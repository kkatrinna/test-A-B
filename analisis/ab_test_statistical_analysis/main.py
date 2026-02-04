import pandas as pd
import numpy as np
from scipy import stats
import statsmodels.api as sm
from statsmodels.stats import power, proportion
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine
import warnings

warnings.filterwarnings('ignore')

# Настройки отображения
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_palette("husl")
pd.set_option('display.max_columns', None)
pd.set_option('display.width', 1000)


# Подключение к базе данных
def connect_to_db():
    """Подключение к SQL Server"""
    connection_string = (
        'mssql+pyodbc://@localhost/marketing_analysis?'
        'driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes'
    )
    return create_engine(connection_string)


def load_ab_test_data(engine):
    """Загрузка данных A/B теста"""

    query = """
    WITH test_data AS (
        SELECT 
            au.group_name,
            au.test_id,
            au.device_type,
            au.browser,
            au.traffic_source,
            CASE WHEN EXISTS (
                SELECT 1 FROM ab_test_events ae 
                WHERE ae.test_id = au.test_id AND ae.event_type = 'purchase'
            ) THEN 1 ELSE 0 END as converted,
            (SELECT COUNT(*) FROM ab_test_events ae2 
             WHERE ae2.test_id = au.test_id) as total_events,
            (SELECT COUNT(*) FROM ab_test_events ae3 
             WHERE ae3.test_id = au.test_id AND ae3.event_type = 'add_to_cart') as cart_events,
            (SELECT AVG(session_duration) FROM ab_test_events ae4 
             WHERE ae4.test_id = au.test_id) as avg_session_duration,
            (SELECT AVG(scroll_depth) FROM ab_test_events ae5 
             WHERE ae5.test_id = au.test_id) as avg_scroll_depth,
            ao.order_amount,
            ao.items_count,
            ao.conversion_time
        FROM ab_test_users au
        LEFT JOIN ab_test_orders ao ON au.test_id = ao.test_id
    )
    SELECT * FROM test_data
    """

    return pd.read_sql(query, engine)


def calculate_basic_metrics(df):
    """Расчет основных метрик"""

    print("=" * 80)
    print("ОСНОВНЫЕ МЕТРИКИ A/B ТЕСТА")
    print("=" * 80)

    # Разделяем данные по группам
    control = df[df['group_name'] == 'control']
    variant = df[df['group_name'] == 'variant']

    # Базовые метрики
    metrics = pd.DataFrame({
        'Метрика': [
            'Размер выборки',
            'Конверсия (%)',
            'Среднее количество событий',
            'Добавления в корзину',
            'Средняя длительность сессии (сек)',
            'Глубина прокрутки (%)',
            'Средний чек ($)',
            'Среднее время до конверсии (сек)'
        ],
        'Control': [
            len(control),
            control['converted'].mean() * 100,
            control['total_events'].mean(),
            control['cart_events'].mean(),
            control['avg_session_duration'].mean(),
            control['avg_scroll_depth'].mean(),
            control['order_amount'].mean(),
            control['conversion_time'].mean()
        ],
        'Variant': [
            len(variant),
            variant['converted'].mean() * 100,
            variant['total_events'].mean(),
            variant['cart_events'].mean(),
            variant['avg_session_duration'].mean(),
            variant['avg_scroll_depth'].mean(),
            variant['order_amount'].mean(),
            variant['conversion_time'].mean()
        ]
    })

    # Расчет относительных изменений
    metrics['Разница'] = metrics['Variant'] - metrics['Control']
    metrics['Относительное изменение (%)'] = (metrics['Variant'] / metrics['Control'] - 1) * 100

    # Форматирование чисел
    for col in ['Control', 'Variant', 'Разница']:
        metrics[col] = metrics[col].apply(lambda x: f"{x:.2f}" if pd.notnull(x) else "N/A")

    metrics['Относительное изменение (%)'] = metrics['Относительное изменение (%)'].apply(
        lambda x: f"{x:.1f}%" if pd.notnull(x) else "N/A"
    )

    print(metrics.to_string(index=False))

    return control, variant


def perform_statistical_tests(control, variant):
    """Выполнение статистических тестов"""

    print("\n" + "=" * 80)
    print("СТАТИСТИЧЕСКИЕ ТЕСТЫ")
    print("=" * 80)

    # 1. Z-тест для пропорций (конверсия)
    control_conversions = control['converted'].sum()
    control_size = len(control)
    variant_conversions = variant['converted'].sum()
    variant_size = len(variant)

    # Вычисляем Z-статистику вручную
    p_control = control_conversions / control_size
    p_variant = variant_conversions / variant_size
    p_pooled = (control_conversions + variant_conversions) / (control_size + variant_size)

    z_score = (p_variant - p_control) / np.sqrt(
        p_pooled * (1 - p_pooled) * (1 / control_size + 1 / variant_size)
    )

    p_value = 2 * (1 - stats.norm.cdf(abs(z_score)))

    print(f"1. Z-тест для конверсии:")
    print(f"   Z-score: {z_score:.4f}")
    print(f"   P-value: {p_value:.6f}")
    print(f"   Статистически значимо: {'ДА' if p_value < 0.05 else 'НЕТ'}")

    # 2. Расчет мощности теста
    effect_size = proportion.proportion_effectsize(p_control, p_variant)
    power_analysis = power.NormalIndPower()
    achieved_power = power_analysis.solve_power(
        effect_size=effect_size,
        nobs1=variant_size,
        alpha=0.05,
        ratio=control_size / variant_size
    )

    print(f"\n2. Мощность теста (Power): {achieved_power:.3f}")
    print(f"   Эффект Коэна (h): {effect_size:.3f}")

    # 3. Доверительные интервалы для разницы
    diff = p_variant - p_control
    se = np.sqrt(p_control * (1 - p_control) / control_size + p_variant * (1 - p_variant) / variant_size)
    ci_lower = diff - 1.96 * se
    ci_upper = diff + 1.96 * se

    print(f"\n3. Доверительный интервал разницы конверсий (95%):")
    print(f"   Разница: {diff:.4f} ({diff * 100:.2f}%)")
    print(f"   ДИ: [{ci_lower:.4f}, {ci_upper:.4f}]")
    print(f"   Относительное изменение: {(p_variant / p_control - 1) * 100:.1f}%")

    # 4. T-тест для метрических переменных
    print(f"\n4. T-тесты для других метрик:")

    metrics_to_test = [
        ('total_events', 'Количество событий'),
        ('cart_events', 'Добавления в корзину'),
        ('avg_session_duration', 'Длительность сессии'),
        ('order_amount', 'Средний чек')
    ]

    results = []
    for metric, name in metrics_to_test:
        # Убираем пропуски
        c_data = control[metric].dropna()
        v_data = variant[metric].dropna()

        if len(c_data) > 1 and len(v_data) > 1:
            t_stat, p_val = stats.ttest_ind(c_data, v_data, equal_var=False)
            results.append({
                'Метрика': name,
                'T-статистика': t_stat,
                'P-value': p_val,
                'Значимо': p_val < 0.05
            })

    results_df = pd.DataFrame(results)
    print(results_df.to_string(index=False))

    return z_score, p_value, diff, ci_lower, ci_upper


def segment_analysis(df):
    """Анализ по сегментам"""

    print("\n" + "=" * 80)
    print("АНАЛИЗ ПО СЕГМЕНТАМ")
    print("=" * 80)

    segments = ['device_type', 'browser', 'traffic_source']

    for segment in segments:
        print(f"\nАнализ по сегменту: {segment}")

        segment_results = []
        for value in df[segment].unique():
            if pd.isna(value):
                continue

            segment_data = df[df[segment] == value]
            if len(segment_data) < 20:
                continue

            control_seg = segment_data[segment_data['group_name'] == 'control']
            variant_seg = segment_data[segment_data['group_name'] == 'variant']

            if len(control_seg) < 10 or len(variant_seg) < 10:
                continue

            conv_control = control_seg['converted'].mean() * 100
            conv_variant = variant_seg['converted'].mean() * 100
            diff = conv_variant - conv_control
            rel_change = (conv_variant / conv_control - 1) * 100 if conv_control > 0 else 0

            segment_results.append({
                'Сегмент': value,
                'Control (%)': f"{conv_control:.2f}",
                'Variant (%)': f"{conv_variant:.2f}",
                'Разница (%)': f"{diff:.2f}",
                'Изменение (%)': f"{rel_change:.1f}%",
                'Размер Control': len(control_seg),
                'Размер Variant': len(variant_seg)
            })

        if segment_results:
            results_df = pd.DataFrame(segment_results)
            results_df = results_df.sort_values('Разница (%)', key=lambda x: pd.to_numeric(x.str.replace('%', '')),
                                                ascending=False)
            print(results_df.to_string(index=False))


def visualize_results(control, variant, diff, ci_lower, ci_upper):
    """Визуализация результатов"""

    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    fig.suptitle('A/B Test Analysis Results', fontsize=16, fontweight='bold')

    # 1. Конверсия по группам
    ax1 = axes[0, 0]
    conv_data = pd.DataFrame({
        'Group': ['Control', 'Variant'],
        'Conversion Rate (%)': [
            control['converted'].mean() * 100,
            variant['converted'].mean() * 100
        ]
    })
    bars = ax1.bar(conv_data['Group'], conv_data['Conversion Rate (%)'],
                   color=['#3498db', '#2ecc71'])
    ax1.set_ylabel('Conversion Rate (%)')
    ax1.set_title('Conversion Rate by Group')
    ax1.grid(True, alpha=0.3)

    # Добавляем значения на столбцы
    for bar in bars:
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width() / 2., height + 0.1,
                 f'{height:.2f}%', ha='center', va='bottom')

    # 2. Распределение конверсий
    ax2 = axes[0, 1]
    conversion_data = pd.DataFrame({
        'Converted': np.concatenate([
            control['converted'].values,
            variant['converted'].values
        ]),
        'Group': ['Control'] * len(control) + ['Variant'] * len(variant)
    })

    # Создаем countplot вручную для лучшего контроля
    control_counts = conversion_data[conversion_data['Group'] == 'Control']['Converted'].value_counts()
    variant_counts = conversion_data[conversion_data['Group'] == 'Variant']['Converted'].value_counts()

    x = np.arange(2)
    width = 0.35

    ax2.bar(x - width / 2, [control_counts.get(0, 0), control_counts.get(1, 0)],
            width, label='Control', color='#3498db')
    ax2.bar(x + width / 2, [variant_counts.get(0, 0), variant_counts.get(1, 0)],
            width, label='Variant', color='#2ecc71')

    ax2.set_xlabel('Converted')
    ax2.set_ylabel('Count')
    ax2.set_title('Conversion Distribution')
    ax2.set_xticks(x)
    ax2.set_xticklabels(['No', 'Yes'])
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # 3. Доверительный интервал разницы
    ax3 = axes[0, 2]
    ax3.errorbar(0, diff * 100, yerr=[(diff - ci_lower) * 100, (ci_upper - diff) * 100],
                 fmt='o', capsize=5, color='#e74c3c', markersize=8)
    ax3.axhline(y=0, color='gray', linestyle='--', alpha=0.5)
    ax3.set_xlim(-0.5, 0.5)
    ax3.set_xticks([])
    ax3.set_ylabel('Difference in Conversion Rate (%)')
    ax3.set_title('95% Confidence Interval for Difference')
    ax3.grid(True, alpha=0.3)

    # Добавляем аннотацию
    ax3.annotate(f'Diff: {diff * 100:.2f}%\nCI: [{ci_lower * 100:.2f}%, {ci_upper * 100:.2f}%]',
                 xy=(0, diff * 100), xytext=(0.2, diff * 100 + 0.2),
                 arrowprops=dict(arrowstyle='->', color='black'))

    # 4. Распределение среднего чека
    ax4 = axes[1, 0]
    order_data = pd.DataFrame({
        'Order Amount': np.concatenate([
            control['order_amount'].dropna().values,
            variant['order_amount'].dropna().values
        ]),
        'Group': ['Control'] * len(control['order_amount'].dropna()) +
                 ['Variant'] * len(variant['order_amount'].dropna())
    })

    order_data.boxplot(column='Order Amount', by='Group', ax=ax4, grid=True)
    ax4.set_title('Order Amount Distribution')
    ax4.set_ylabel('Order Amount ($)')
    ax4.set_xlabel('')

    # 5. Распределение событий
    ax5 = axes[1, 1]
    events_data = pd.DataFrame({
        'Total Events': np.concatenate([
            control['total_events'].values,
            variant['total_events'].values
        ]),
        'Group': ['Control'] * len(control) + ['Variant'] * len(variant)
    })

    events_data.boxplot(column='Total Events', by='Group', ax=ax5, grid=True)
    ax5.set_title('Total Events Distribution')
    ax5.set_ylabel('Number of Events')
    ax5.set_xlabel('')

    # 6. Конверсия по устройствам
    ax6 = axes[1, 2]
    device_data = pd.concat([control, variant])
    device_conv = device_data.groupby(['device_type', 'group_name'])['converted'].mean().unstack() * 100

    device_conv.plot(kind='bar', ax=ax6, color=['#3498db', '#2ecc71'])
    ax6.set_title('Conversion Rate by Device Type')
    ax6.set_ylabel('Conversion Rate (%)')
    ax6.set_xlabel('Device Type')
    ax6.legend(title='Group')
    ax6.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('ab_test_results.png', dpi=300, bbox_inches='tight')
    plt.show()

    print(f"\nГрафики сохранены в файл: ab_test_results.png")


def calculate_sample_size():
    """Расчет необходимого размера выборки"""

    print("\n" + "=" * 80)
    print("РАСЧЕТ НЕОБХОДИМОГО РАЗМЕРА ВЫБОРКИ")
    print("=" * 80)

    # Параметры для расчета
    baseline_rate = 0.08  # 8% конверсия в контроле
    mde = 0.15  # Minimum Detectable Effect (15%)
    alpha = 0.05  # Уровень значимости
    power = 0.8  # Мощность теста

    effect_size = proportion.proportion_effectsize(
        baseline_rate,
        baseline_rate * (1 + mde)
    )

    power_analysis = power.NormalIndPower()
    required_n = power_analysis.solve_power(
        effect_size=effect_size,
        power=power,
        alpha=alpha,
        ratio=1  # равные группы
    )

    print(f"Базовый уровень конверсии: {baseline_rate * 100:.1f}%")
    print(f"Минимальный детектируемый эффект (MDE): {mde * 100:.0f}%")
    print(f"Уровень значимости (alpha): {alpha}")
    print(f"Мощность теста (power): {power}")
    print(f"Эффект Коэна (h): {effect_size:.3f}")
    print(f"\nТребуемый размер выборки НА ГРУППУ: {required_n:.0f} пользователей")
    print(f"Общий размер выборки: {required_n * 2:.0f} пользователей")

    # Проверяем, достаточно ли было данных в нашем тесте
    actual_power = power_analysis.solve_power(
        effect_size=effect_size,
        nobs1=5000,  # предположим размер группы
        alpha=alpha,
        ratio=1
    )

    print(f"\nПри размере группы 5000 пользователей:")
    print(f"Достигнутая мощность: {actual_power:.3f}")


def main():
    """Основная функция"""

    print("A/B TEST STATISTICAL ANALYSIS")
    print("=" * 80)

    try:
        # Подключаемся к базе данных
        engine = connect_to_db()

        # Загружаем данные
        print("Загрузка данных из базы данных...")
        df = load_ab_test_data(engine)
        print(f"Загружено {len(df)} записей")

        # Основные метрики
        control, variant = calculate_basic_metrics(df)

        # Статистические тесты
        z_score, p_value, diff, ci_lower, ci_upper = perform_statistical_tests(control, variant)

        # Анализ по сегментам
        segment_analysis(df)

        # Расчет размера выборки
        calculate_sample_size()

        # Визуализация
        visualize_results(control, variant, diff, ci_lower, ci_upper)

        # Заключение
        print("\n" + "=" * 80)
        print("ЗАКЛЮЧЕНИЕ И РЕКОМЕНДАЦИИ")
        print("=" * 80)

        if p_value < 0.05:
            print("✅ СТАТИСТИЧЕСКИ ЗНАЧИМЫЙ РЕЗУЛЬТАТ")
            print(f"   Новая версия (variant) показала увеличение конверсии на {diff * 100:.2f}%")
            print(
                f"   Относительное улучшение: {(variant['converted'].mean() / control['converted'].mean() - 1) * 100:.1f}%")

            if diff > 0:
                print("\n🎯 РЕКОМЕНДАЦИЯ: Внедрить новую версию")
            else:
                print("\n⚠️  РЕКОМЕНДАЦИЯ: Оставить текущую версию")
        else:
            print("❌ НЕТ СТАТИСТИЧЕСКОЙ ЗНАЧИМОСТИ")
            print("   Разница в конверсии не является статистически значимой")
            print("\n🔍 РЕКОМЕНДАЦИЯ:")
            print("   1. Увеличить размер выборки")
            print("   2. Продлить длительность теста")
            print("   3. Провести анализ по сегментам для поиска локальных эффектов")

        # Бизнес-оценка
        print("\n" + "=" * 80)
        print("БИЗНЕС-ОЦЕНКА ЭФФЕКТА")
        print("=" * 80)

        monthly_users = 100000  # предположим
        avg_order_value = variant['order_amount'].mean()

        if not np.isnan(avg_order_value) and diff > 0:
            additional_conversions = monthly_users * diff
            additional_revenue = additional_conversions * avg_order_value

            print(f"Предполагаемый месячный трафик: {monthly_users:,} пользователей")
            print(f"Средний чек: ${avg_order_value:.2f}")
            print(f"Дополнительные конверсии в месяц: {additional_conversions:.0f}")
            print(f"Дополнительная выручка в месяц: ${additional_revenue:,.2f}")
            print(f"Годовая дополнительная выручка: ${additional_revenue * 12:,.2f}")

    except Exception as e:
        print(f"Ошибка: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
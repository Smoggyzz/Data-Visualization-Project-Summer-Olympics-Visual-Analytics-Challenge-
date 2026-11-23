# task1-data · 任务一：数据体检与口径定义

负责人：任务一成员。

## 交付物

- `data/processed/olympics_clean.parquet`：清洗后的数据集；
- `contracts/caliber_spec.md`：口径说明书 v1.0；
- `contracts/sport_map.csv`：体育大类归一映射；
- `quality/checks/`：至少 5 项可复现的数据质量检查；
- `requirements.txt`：Python 依赖。

## 必须冻结的字段

| 字段 | 说明 |
| --- | --- |
| `sport_norm` | 2020 年前后大类漂移归一后的体育大类 |
| `event_key` | 小项唯一键 |
| `event_key_quality` | `specific` / `generic`，标记 2020+ 泛化情况 |
| `is_team_event` | 是否团体项目 |
| `is_1906` | 是否 1906 届 |
| `include_flag` | 是否纳入默认分析 |

## 与其他任务的接口

- 任务二只消费本目录产物，不自行定义小项；
- 口径变更必须更新 `caliber_spec.md` 并通知任务二、任务三、任务四；
- 原始数据放在 `data/raw/`，清洗产物放 `data/processed/`，两者都不入库。

## 冻结时间

W1 D5。冻结后如需变更，走口径变更单。

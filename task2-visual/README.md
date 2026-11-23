# task2-visual · 任务二：百年奥运全景

负责人：任务二成员。完整设计见 [docs/任务二方案.md](../docs/任务二方案.md)。

## 交付物

- `pipeline/`：Python 预聚合，输出图表 JSON 与 `shared/metrics/`；
- `site/`：Vite + TypeScript + Apache ECharts 数据故事站；
- `exports/`：PNG@4x 与 SVG 图资产；
- `report/`：图注、≥100 字解读、图号登记；
- `video/`：90 秒视频分镜；
- `poster/`：海报主图素材。

## 图表优先级

- P0：A1 双口径总榜、A2 逐届演变、B1 九国矩阵、C1 女性双弧线、C2 参与≠产出、D1 项目生命线；
- P1：B2 国家效率前沿、D2 项目结构变迁；
- P2：X1 国家×项目矩阵、X2 项目性别差哑铃。

## 常用命令

```bash
python -m pipeline.build --caliber conservative_event --exclude-1906
python -m pipeline.validate
cd site && npm install && npm run dev
npm run export:figures
npm run build:offline
```

## 约束

- 所有图表必须使用 Apache ECharts；
- 每幅图必须声明口径、分母、是否含 1906；
- 站点深色主题，PDF/海报使用浅色主题；
- 不提交原始数据与大体积导出中间产物。

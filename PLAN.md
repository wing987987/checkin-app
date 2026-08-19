# 昭臣打卡 App 开发计划

> 工人打卡应用：GPS 定位自动识别项目与班次，按打卡闭环计算工时，按月/项目/班组生成报表。
> 后端复用 seahorizon-backgroud（同一 Java 进程，节约内存），数据通过 `ck_` 表前缀与采购 App 完全隔离。

## 总体架构

| 层 | 方案 |
|---|---|
| App | Flutter（本项目），与采购 App 相同的 debug/test/prod 三环境结构 |
| 后端 | seahorizon-backgroud 新增 `com.seahorizon.checkin` 包（controller/service/entity/mapper 独立） |
| 接口前缀 | `/api/ck/**`（与采购 App 的 `/api/**` 区分），JWT 中增加 `app=checkin` 声明防止跨 App 串用 token |
| 数据库 | 同一 MySQL 实例，打卡表统一 `ck_` 前缀，Flyway 迁移从 V30 起编号 |
| 账号体系 | 独立 `ck_user` 表（admin 主管理员 / worker 工人），与 user_info 不相通 |
| 图片 | 复用现有 OSS 预签名上传，打卡照片自动叠加水印（GPS + 时间）后归档 |

## 需求映射（来自手写需求稿）

### 主管理权限（admin）
1. 可创建项目（项目带 GPS 定位坐标）
2. 可增减人员
3. 可调整数据（打卡记录修正）
4. 可分配班组
5. 报表：按项目 + 按月

### 操作流程（worker）
1. **自动识别排班**：白班 6:30-11:30、13:00-17:30，打卡允许 ±5 分钟容差；夜班排班含高温调整，预留配置窗口（细节后议）
2. **自动识别项目**：按 GPS 定位匹配最近的项目围栏
3. **工时闭环**：白班四次打卡（上午上/上午下/下午上/下午下）= 1 个工；夜班两次（晚上上/早上上）= 1 个工
4. **加班**：只计时不计工（与白班/夜班时段冲突处理复杂，单独阶段实现）

### 数据整理
1. 每个工人每月生成报表（付工资用）
2. 每个项目每月每班组生成报表
3. 打卡照片自动生成水印（GPS、时间）并归档

## 开发阶段

### 阶段一：项目骨架（本次完成）
- Flutter 项目 + 双 flavor（prod/staging）+ ENV dart-define + adb reverse 8082
- EnvConfig / DioClient / AuthProvider / 登录页占位
- 独立 Android 签名证书（checkin-release.jks）

### 阶段二：账号与鉴权（后端 ck 模块地基）
- Flyway：`ck_user`（username/password BCrypt/realName/phone/role/status/deleted）
- `/api/ck/auth/login|me`，JWT 增加 `app` 声明；`CkAuthInterceptor` 校验 `app=checkin` 且用户在 ck_user
- 初始 admin 账号迁移脚本（模式同 V27）
- App 登录流程联调（登录页已就绪）

### 阶段三：项目与人员管理（admin）
- `ck_project`（name/gpsLat/gpsLng/fenceRadius/status）
- `ck_team` 班组、`ck_worker_assign` 人员-项目-班组分配
- admin 端页面：项目 CRUD（创建时采集当前 GPS）、人员增减、班组分配

### 阶段四：打卡核心（worker）
- `ck_shift` 班次配置（白班时段 ±5 分钟容差；夜班留调整窗口）
- `ck_clock_record`（userId/projectId/shiftType/checkPoint/gps/photoUrls/at）
- GPS 自动识别项目（就近匹配 + 围栏半径校验）
- 打卡闭环判定：白班 4 次 / 夜班 2 次 = 1 工
- 拍照打卡 → OSS 上传 → 水印（GPS + 时间）→ 归档

### 阶段五：工时与报表
- `ck_workday` 每日工时聚合（工人 × 项目 × 日期 × 工数）
- 工人月报（付工资用）：按人按月汇总工数/工时
- 项目报表：按项目 × 月 × 班组汇总
- admin 数据调整入口（修正记录留痕）

### 阶段六：加班与夜班完善（难点，单独讨论后细化）
- 加班只计时不计工，需处理与白班/夜班时段的冲突判定
- 夜班高温季排班调整窗口

## 待确认事项
1. 夜班具体时段与高温调整规则
2. 打卡容差 ±5 分钟是否需要按项目配置
3. GPS 围栏半径默认值（建议 300m，可项目级覆盖）
4. 报表是否需要导出（Excel）还是仅 App 内查看
5. 加班计时的上限与审批规则

## 环境说明
- **F5 调试**：`.vscode/launch.json` 两个配置（prod/staging），启动前自动 `adb reverse 8082` 连本地后端
- **测试包**：`flutter build apk --flavor staging --dart-define=ENV=test`，applicationId 带 `.test` 后缀，应用名「打卡测试」
- **生产包**：`flutter build apk --flavor prod --dart-define=ENV=prod`，应用名「昭臣打卡」，release 签名缺失时构建直接失败
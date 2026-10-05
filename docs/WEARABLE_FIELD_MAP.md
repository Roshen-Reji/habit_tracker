# Wearable Field Mapping & Data Contracts (MVP 4.1)

This document specifies the exact mapping between external wearable telemetry (Samsung Health / Health Connect / Mock), the platform channel payloads, and internal Hive storage models.

---

## 1. Platform Channel Payload Specification

- **Channel Name**: `com.example.habit_tracker/samsung_health`
- **Method**: `getDailySummary(startMs, endMs)`
- **Response Format**: `Map<String, dynamic>` containing array fields for each domain.

### 1.1 Daily Activity (`activities`)
| Payload Key | Type | Unit / Range | Model Field | Hive Type | Fallback Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `dayKey` | String | `yyyy-MM-dd` | `DailyActivity.dayKey` | String | Required |
| `steps` | int | count (>= 0) | `DailyActivity.steps` | int | 0 |
| `distanceM` | double? | meters | `DailyActivity.distanceM` | double? | `null` (never fabricated) |
| `activeKcal` | double? | kcal | `DailyActivity.activeKcal` | double? | `null` |
| `totalKcal` | double? | kcal | `DailyActivity.totalKcal` | double? | `null` |
| `activeMinutes`| int? | minutes | `DailyActivity.activeMinutes`| int? | `null` |
| `floors` | int? | count | `DailyActivity.floors` | int? | `null` |
| `restingHr` | int? | bpm | `DailyActivity.restingHr` | int? | `null` |
| `avgHr` | int? | bpm | `DailyActivity.avgHr` | int? | `null` |
| `spo2Avg` | double? | % (0 - 100) | `DailyActivity.spo2Avg` | double? | `null` |
| `stepGoal` | int? | count | `DailyActivity.stepGoal` | int? | `null` (defaults to 10,000 for progress display) |

### 1.2 Sleep Sessions (`sleep`)
| Payload Key | Type | Unit / Range | Model Field | Hive Type | Fallback Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | String | unique ID | `SleepSession.externalId` | String | Required |
| `dayKey` | String | `yyyy-MM-dd` | `SleepSession.dayKey` | String | Required |
| `startTime` | int | epoch ms | `SleepSession.start` | DateTime | Required |
| `endTime` | int | epoch ms | `SleepSession.end` | DateTime | Required |
| `totalMinutes`| int | minutes | `SleepSession.durationMin` | int | `(end - start) ~/ 60000` |
| `score` | int? | 0 - 100 | `SleepSession.score` | int? | `null` (never default 80 or 82) |
| `deepMinutes` | int? | minutes | `SleepSession.deepMin` | int? | `null` |
| `lightMinutes`| int? | minutes | `SleepSession.lightMin` | int? | `null` |
| `remMinutes` | int? | minutes | `SleepSession.remMin` | int? | `null` |
| `awakeMinutes`| int? | minutes | `SleepSession.awakeMin` | int? | `null` |
| `isNap` | bool | boolean | `SleepSession.isNap` | bool | `false` |

### 1.3 Exercise Sessions (`exercises`)
| Payload Key | Type | Unit / Range | Model Field | Hive Type | Fallback Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | String | unique ID | `ExerciseSession.externalId`| String | Required |
| `type` | String | exercise kind | `ExerciseSession.type` | String | `'workout'` |
| `title` | String?| custom label | `ExerciseSession.title` | String? | `null` |
| `startTime` | int | epoch ms | `ExerciseSession.start` | DateTime | Required |
| `endTime` | int | epoch ms | `ExerciseSession.end` | DateTime | Required |
| `durationMin` | int | minutes | `ExerciseSession.durationMin`| int | Required |
| `activeKcal` | double?| kcal | `ExerciseSession.activeKcal` | double? | `null` |
| `totalKcal` | double?| kcal | `ExerciseSession.totalKcal` | double? | `null` |
| `avgHr` | int? | bpm | `ExerciseSession.avgHr` | int? | `null` |
| `maxHr` | int? | bpm | `ExerciseSession.maxHr` | int? | `null` |

### 1.4 Body Composition (`bodyComposition`)
| Payload Key | Type | Unit / Range | Model Field | Hive Type | Fallback Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `time` | int | epoch ms | `BodyCompSample.timestamp` | DateTime | Required |
| `weight` | double?| kg | `BodyCompSample.weightKg` | double? | `null` (never default 72.4) |
| `bodyFatPct` | double?| % | `BodyCompSample.bodyFatPct`| double? | `null` (never default 16.8) |
| `skeletalMuscleMass` | double?| kg | `BodyCompSample.skeletalMuscleMassKg` | double? | `null` (never default 35.1) |
| `bmi` | double?| kg/m² | `BodyCompSample.bmi` | double? | `null` (never default 22.8) |

### 1.5 Energy Score (`energyScore`)
| Payload Key | Type | Unit / Range | Model Field | Hive Type | Fallback Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `dayKey` | String | `yyyy-MM-dd` | `EnergyScoreDay.dayKey` | String | Required |
| `score` | int | 0 - 100 | `EnergyScoreDay.score` | int | Required |
| `sleepScore` | double?| factor (0-100)| `EnergyScoreDay.sleepScore` | double? | `null` |
| `activityScore`| double?| factor (0-100)| `EnergyScoreDay.activityScore` | double? | `null` |
| `sleepHr` | double?| factor (0-100)| `EnergyScoreDay.sleepHr` | double? | `null` |
| `sleepHrv` | double?| factor (0-100)| `EnergyScoreDay.sleepHrv` | double? | `null` |

### 1.6 AGEs Index (`agesIndex`)
- **Origin**: Samsung Galaxy Watch 7 BioActive Sensor.
- **Access Status**: Requires Samsung Privileged Partner SDK for direct query. In MVP 4.1, users enter this value manually via `AgesLogSheet`.
- **Field**: `AgesSample.score` (`double`), `timestamp` (`DateTime`), `extraJson` (`String?` containing optional trend and notes).

---

## 2. Calorie Reconciliation & De-duplication

When wearable exercise sessions sync:
1. `CalorieReconciler.reconcileBurnEntries(...)` checks manual `BurnEntry` items in the diet log for the day.
2. If a manual entry starts within **±30 minutes** and has duration within **25%** of a synced wearable session:
   - The manual entry is marked with `supersededBy = session.externalId`.
   - The manual entry is omitted from total daily burned calculations.
   - If the wearable session is deleted or revoked, the manual entry is restored automatically.
3. If no matching manual entry exists:
   - A synthetic `BurnEntry` is appended to the diet log with `source = 'samsung_health'` or `source = 'wearable'`.

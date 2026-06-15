import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Enums stored as TEXT
// ---------------------------------------------------------------------------

enum DayType { fullDay, wfh, halfDay, leave, officialOff, weeklyOff }

enum ShiftSource { manual, notification, geofence, nfc }

enum NfcAction { toggle, clockIn, clockOut }

enum TaskPriority { low, medium, high }

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

@DataClassName('Profile')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get colorHex => text().withDefault(const Constant('#2563EB'))();
  TextColumn get iconName => text().withDefault(const Constant('work'))();
  IntColumn get targetDailyMinutes =>
      integer().withDefault(const Constant(480))();
  IntColumn get targetWeeklyMinutes =>
      integer().withDefault(const Constant(2400))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('WorkDay')
class WorkDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()(); // store as midnight UTC
  TextColumn get dayType =>
      textEnum<DayType>().withDefault(Constant(DayType.fullDay.name))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, date},
      ];
}

@DataClassName('Shift')
class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workDayId =>
      integer().references(WorkDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get clockInAt => dateTime()();
  DateTimeColumn get clockOutAt => dateTime().nullable()();
  RealColumn get clockInLat => real().nullable()();
  RealColumn get clockInLng => real().nullable()();
  RealColumn get clockOutLat => real().nullable()();
  RealColumn get clockOutLng => real().nullable()();
  TextColumn get source =>
      textEnum<ShiftSource>().withDefault(Constant(ShiftSource.manual.name))();
}

@DataClassName('Break')
class Breaks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shiftId =>
      integer().references(Shifts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
}

@DataClassName('TaskType')
class TaskTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get colorHex => text().withDefault(const Constant('#6366F1'))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

@DataClassName('Task')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.setNull).nullable()();
  IntColumn get shiftId =>
      integer().references(Shifts, #id, onDelete: KeyAction.setNull).nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get taskTypeId =>
      integer().references(TaskTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  IntColumn get manualDurationMinutes => integer().nullable()();
  // Task weightage (1–5) — replaces duration as the effort/importance metric.
  IntColumn get weight => integer().withDefault(const Constant(1))();
  TextColumn get priority =>
      textEnum<TaskPriority>().withDefault(Constant(TaskPriority.medium.name))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('TaskMilestone')
class TaskMilestones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('TaskTimeLog')
class TaskTimeLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get shiftId =>
      integer().references(Shifts, #id, onDelete: KeyAction.setNull).nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
}

@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.setNull).nullable()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.setNull).nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))(); // markdown
  TextColumn get colorHex => text().withDefault(const Constant('#FBBF24'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('OffDayRule')
class OffDayRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade).nullable()();
  // Bitmask: bit 0 = Mon, bit 1 = Tue ... bit 6 = Sun
  // e.g. Sunday off = 64, Sun+Sat = 64+32 = 96
  IntColumn get weeklyOffMask => integer().withDefault(const Constant(64))();
  // true = every other Saturday is also off (alternating)
  BoolColumn get alternateSatOff =>
      boolean().withDefault(const Constant(false))();
  // The reference Saturday for alternating (the first "off" Saturday's epoch day)
  IntColumn get alternateSatRefEpochDay => integer().nullable()();
}

@DataClassName('Holiday')
class Holidays extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade).nullable()();
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('NfcTag')
class NfcTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tagUid => text().unique()();
  TextColumn get label => text().withLength(min: 1, max: 100)();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get action =>
      textEnum<NfcAction>().withDefault(Constant(NfcAction.toggle.name))();
}

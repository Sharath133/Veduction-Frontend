/// Compile-time flags (override with `--dart-define=SHOW_STUDENT_ADMIN_PORTAL=true`).
const bool kShowStudentAdminPortal = bool.fromEnvironment(
  'SHOW_STUDENT_ADMIN_PORTAL',
  defaultValue: false,
);

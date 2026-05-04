import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';

/// Employee profile tab content. Renders the shared [ProfileScreen]
/// in embedded mode so the parent shell controls the AppBar.
class EmployeeProfileScreen extends StatelessWidget {
  const EmployeeProfileScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProfileScreen(embeddedInTab: true);
}

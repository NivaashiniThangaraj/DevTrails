import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    try {
      Provider.of<AegisProvider>(context, listen: false).reset();
    } catch (_) {}

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/onboarding',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AegisProvider>(context);
    final worker = provider.worker;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),

      body: worker == null
          ? const Center(child: CircularProgressIndicator()) // 🔥 loading state
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // 👤 Profile Icon (dynamic initial)
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      child: Text(
                        worker.name.isNotEmpty
                            ? worker.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 👤 Name
                  Center(
                    child: Text(
                      worker.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 📄 REAL DATA
                  Text("Phone: ${worker.phone}"),
                  const SizedBox(height: 10),

                  Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      "Plan: ${worker.planTier[0].toUpperCase()}${worker.planTier.substring(1)}",
    ),
    TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/plans'); // 🔥 GO TO PLAN SCREEN
      },
      child: const Text("Change"),
    ),
  ],
),
                  const SizedBox(height: 10),

                  Text("Zone: ${worker.zone}"),

                  const Spacer(),

                  // 🔴 Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _logout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
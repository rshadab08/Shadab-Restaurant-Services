import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Shadab Restaurant Services",
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? user;
  DateTime? selectedDate;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final messageController = TextEditingController();

  final bookingName = TextEditingController();
  final bookingEmail = TextEditingController();
  final bookingGuests = TextEditingController();

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((u) {
      setState(() => user = u);
    });

    ui_web.platformViewRegistry.registerViewFactory(
      'map-html',
      (int viewId) => html.IFrameElement()
        ..src =
            "https://www.google.com/maps/embed?pb=!1m18!1m12..."
        ..style.border = 'none',
    );
  }

  bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 700;

  Future<void> logout() async =>
      await FirebaseAuth.instance.signOut();

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> sendContact() async {
    await FirebaseFirestore.instance.collection("contacts").add({
      "name": nameController.text,
      "email": emailController.text,
      "message": messageController.text,
      "createdAt": Timestamp.now(),
    });
  }

  Future<void> createBooking() async {
    await FirebaseFirestore.instance.collection("bookings").add({
      "name": bookingName.text,
      "email": bookingEmail.text,
      "guests": bookingGuests.text,
      "date": selectedDate,
      "createdAt": Timestamp.now(),
    });

    final result = await FirebaseFunctions.instance
        .httpsCallable("createCheckoutSession")
        .call();

    html.window.location.href = result.data["url"];
  }

  Future<bool> isAdmin() async {
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();
    return doc.exists && doc["role"] == "admin";
  }

  Future<void> openAdmin(BuildContext context) async {
    if (await isAdmin()) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AdminPanel()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin Only")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shadab Restaurant Services"),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                  child: Text(user!.email ?? "",
                      style:
                          const TextStyle(color: Colors.white))),
            ),
          if (user == null)
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginPage())),
              child: const Text("Login",
                  style: TextStyle(color: Colors.white)),
            ),
          if (user == null)
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SignUpPage())),
              child: const Text("Sign Up",
                  style: TextStyle(color: Colors.white)),
            ),
          if (user != null)
            TextButton(
              onPressed: logout,
              child: const Text("Logout",
                  style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: () => openAdmin(context),
            child: const Text("Admin",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(60),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
              ),
              child: const Column(
                children: [
                  Text("Premium Dining Experience",
                      style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            buildCard("Contact Us", buildContactForm()),
            buildCard("Book Table", buildBookingForm()),
          ],
        ),
      ),
    );
  }

  Widget buildCard(String title, Widget child) {
    return Container(
      width: 600,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 10)
        ],
      ),
      child: Column(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        child
      ]),
    );
  }

  Widget buildContactForm() {
    return Column(children: [
      TextField(controller: nameController,
          decoration: const InputDecoration(labelText: "Name")),
      TextField(controller: emailController,
          decoration: const InputDecoration(labelText: "Email")),
      TextField(controller: messageController,
          decoration: const InputDecoration(labelText: "Message")),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: sendContact,
          child: const Text("Send Message"))
    ]);
  }

  Widget buildBookingForm() {
    return Column(children: [
      TextField(controller: bookingName,
          decoration: const InputDecoration(labelText: "Name")),
      TextField(controller: bookingEmail,
          decoration: const InputDecoration(labelText: "Email")),
      TextField(controller: bookingGuests,
          decoration: const InputDecoration(labelText: "Guests")),
      const SizedBox(height: 10),
      ElevatedButton(
          onPressed: () => pickDate(context),
          child: Text(selectedDate == null
              ? "Select Date"
              : selectedDate.toString().split(" ")[0])),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: createBooking,
          child: const Text("Reserve & Pay"))
    ]);
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(children: [
            TextField(controller: email,
                decoration:
                    const InputDecoration(labelText: "Email")),
            TextField(controller: pass,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Password")),
            ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance
                      .signInWithEmailAndPassword(
                          email: email.text,
                          password: pass.text);
                  Navigator.pop(context);
                },
                child: const Text("Login"))
          ]),
        ),
      ),
    );
  }
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(children: [
            TextField(controller: email,
                decoration:
                    const InputDecoration(labelText: "Email")),
            TextField(controller: pass,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Password")),
            ElevatedButton(
                onPressed: () async {
                  final cred = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                          email: email.text,
                          password: pass.text);
                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(cred.user!.uid)
                      .set({"role": "user"});
                  Navigator.pop(context);
                },
                child: const Text("Create Account"))
          ]),
        ),
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bookings")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(
                title: Text(doc["name"]),
                subtitle: Text(doc["email"]),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PetsDetailsPage extends StatefulWidget {
  const PetsDetailsPage({super.key});

  @override
  State<PetsDetailsPage> createState() => _PetsDetailsPageState();
}

class _PetsDetailsPageState extends State<PetsDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets Details'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: Center(child: Text('Pets Details Page')),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   Size size = MediaQuery.of(context).size;
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('Pets Details'),
  //       leading: IconButton(
  //         icon: Icon(Icons.arrow_back),
  //         onPressed: () {
  //           context.pop();
  //         },
  //       ),
  //     ),
  //     body: SizedBox(
  //       width: size.width * 0.9,
  //       height: size.height * 0.5,
  //       child: Stack(
  //         children: [
  //           Container(
  //             width: size.width,
  //             height: size.height * 0.5,
  //             color: Colors.blue,
  //             decoration: BoxDecoration(
  //               color: Colors.blue.withValues(alpha: 0.5),
  //             ),
  //             child: Stack(
  //               children: [
  //                 Positioned(
  //                   left: -60,
  //                   top: 30,
  //                   child: Transform.rotate(
  //                     angle: -11.5,
  //                     child: Image.asset(
  //                       'assets/images/rTnrpap6c.png',
  //                       height: 200,
  //                       color: Colors.white,
  //                     ),
  //                   ),
  //                 ),
  //                 Positioned(
  //                   left: -60,
  //                   top: 0,
  //                   child: Transform.rotate(
  //                     angle: 12,
  //                     child: Image.asset(
  //                       'assets/images/rTnrpap6c.png',
  //                       height: 200,
  //                       color: Colors.white,
  //                     ),
  //                   ),
  //                 ),
  //                 Positioned(
  //                   bottom: 10,
  //                   left: 0,
  //                   right: 0,
  //                   child: Hero(
  //                     tag: 'assets/images/cat.png',
  //                     child: Image.asset(
  //                       'assets/images/rTnrpap6c.png',
  //                       height: size.height * 0.45,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}

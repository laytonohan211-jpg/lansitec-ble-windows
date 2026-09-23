import 'package:flutter/material.dart';
import 'package:flutter_blue/modules/settings/on_boards.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final PageController _pageController = PageController();
  int currentPage = 0;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.send),
            label: Text("Send"),
            onPressed: () {},
          ),
          const SizedBox(width: 15),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(),
            child: Text("Save"),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: size.height * 0.7,
            color: const Color.fromARGB(255, 128, 196, 163),
            child: PageView.builder(
              itemCount: onBoardData.length,
              onPageChanged: (value) => setState(() => currentPage = value),
              controller: _pageController,
              itemBuilder: (context, index) {
                return onBoardingItems(size, index);
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              if (currentPage == onBoardData.length - 1) {
                context.push('/pets_home');
              } else {
                _pageController.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              }
            },
            child: Container(
              height: 60,
              width: size.width * 0.6,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  currentPage == onBoardData.length - 1
                      ? "Get Started"
                      : "Continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(
                onBoardData.length,
                (index) => indicatorForSlider(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget indicatorForSlider(int? index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      height: 10,
      width: currentPage == index ? 20 : 10,
      margin: EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color:
            currentPage == index
                ? Colors.orange
                : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Column onBoardingItems(Size size, int index) {
    return Column(
      children: [
        Container(
          height: size.height * 0.4,
          width: size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.blueGrey,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    height: 240,
                    width: size.width * 0.9,
                    color: Colors.amber,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 5,
                          left: -40,
                          height: 130,
                          width: 130,
                          child: Transform.rotate(
                            angle: -11,
                            child: Image.asset(
                              "assets/images/rTnrpap6c.png",
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          right: -20,
                          height: 130,
                          width: 130,
                          child: Transform.rotate(
                            angle: -12,
                            child: Image.asset(
                              "assets/images/rTnrpap6c.png",
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                right: 50,
                child: Image.asset(
                  onBoardData[index].image,
                  height: 100,
                  width: 100,
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 30),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 35,
              color: Colors.black,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
            children: [
              TextSpan(text: "Find you "),
              TextSpan(
                text: "Dream\n",
                style: TextStyle(
                  color: Colors.lightBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(text: "Pet here"),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          onBoardData[index].text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5, color: Colors.black38),
        ),
      ],
    );
  }
}

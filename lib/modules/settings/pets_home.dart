import 'package:flutter/material.dart';
import 'package:flutter_blue/modules/settings/cats_model.dart';
import 'package:go_router/go_router.dart';

class PetsHomePage extends StatefulWidget {
  const PetsHomePage({super.key});

  @override
  State<PetsHomePage> createState() => _PetsHomePageState();
}

class _PetsHomePageState extends State<PetsHomePage> {
  int selectedCategory = 0;
  int selectedIndex = 0;
  List<IconData> bottomIcons = [
    Icons.home_outlined,
    Icons.favorite_outline_rounded,
    Icons.chat,
    Icons.person_outline_rounded,
  ];
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets Home'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            headerParts(),
            SizedBox(height: 20),
            joinNow(),
            SizedBox(height: 30),
            categoryViewAll('Categories'),
            SizedBox(height: 25),
            categoryViewItem(),
            SizedBox(height: 20),
            categoryViewAll('Adot Pet'),
            SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(cats.length, (index) {
                  final cat = cats[index];
                  return petsItems(size, cat);
                }),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(bottomIcons.length, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedIndex = index;
                });
              },
              child: Container(
                height: 60,
                width: 50,
                padding: EdgeInsets.all(5),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Icon(
                          bottomIcons[index],
                          color:
                              selectedIndex == index
                                  ? Colors.blue
                                  : Colors.black.withValues(alpha: 0.6),
                        ),
                        SizedBox(height: 5),
                        selectedIndex == index
                            ? Container(
                              height: 5,
                              width: 5,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            )
                            : Container(),
                      ],
                    ),
                    index == 2
                        ? Positioned(
                          right: 0,
                          top: -10,
                          child: Container(
                            padding: EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              "3",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        : Container(),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Padding petsItems(Size size, Cat cat) {
    return Padding(
      padding: EdgeInsets.only(left: 20),
      child: GestureDetector(
        onTap: () => {context.push('/pets_details')},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: size.height * 0.3,
            width: size.width * 0.55,
            color: cat.color.withValues(alpha: 0.5),
            child: Stack(
              children: [
                Positioned(
                  bottom: -10,
                  right: -10,
                  height: 100,
                  width: 100,
                  child: Transform.rotate(
                    angle: 12,
                    child: Image.asset(
                      'assets/images/rTnrpap6c.png',
                      color: cat.color,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  left: -25,
                  height: 90,
                  width: 90,
                  child: Transform.rotate(
                    angle: -11.5,
                    child: Image.asset(
                      'assets/images/rTnrpap6c.png',
                      color: cat.color,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -10,
                  right: 10,
                  child: Hero(
                    tag: cat.image,
                    child: Image.asset(cat.image, height: size.height * 0.25),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "${cat.location} km",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(
                          cat.fav
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline_rounded,
                          color:
                              cat.fav
                                  ? Colors.red
                                  : Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SingleChildScrollView categoryViewItem() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(width: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.black12.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.pets, color: Colors.amber),
          ),
          ...List.generate(categories.length, (index) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = index;
                  });
                },
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color:
                            selectedCategory == index
                                ? Colors.blue
                                : Colors.black12.withValues(alpha: 0.03),
                      ),
                      child: Text(
                        categories[index],
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              selectedCategory == index
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Padding categoryViewAll(name) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          Spacer(),
          Row(
            children: [
              Text(
                "View All",
                style: TextStyle(fontSize: 12, color: Colors.amber),
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Padding headerParts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(width: 5),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.blue,
                size: 18,
              ),
              SizedBox(width: 5),
            ],
          ),
          Row(
            children: [
              Text.rich(
                TextSpan(
                  text: 'Chicago, ',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(
                      text: 'US',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.search),
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Icon(Icons.notifications_outlined),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        height: 7,
                        width: 7,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Padding joinNow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          width: double.infinity,
          color: Colors.blue,
          child: Stack(
            children: [
              Positioned(
                bottom: -20,
                right: -30,
                width: 100,
                height: 100,
                child: Transform.rotate(
                  angle: 12,
                  child: Image.asset(
                    'assets/images/rTnrpap6c.png',
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ),
              Positioned(
                bottom: -35,
                left: -15,
                width: 100,
                height: 100,
                child: Transform.rotate(
                  angle: -12,
                  child: Image.asset(
                    'assets/images/rTnrpap6c.png',
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ),
              Positioned(
                top: -40,
                left: 120,
                width: 110,
                height: 110,
                child: Transform.rotate(
                  angle: -16,
                  child: Image.asset(
                    'assets/images/rTnrpap6c.png',
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 20,
                height: 170,
                child: Image.asset(
                  'assets/images/cat.png',
                  height: 150,
                  width: 150,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How do you\n feel today?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Join Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

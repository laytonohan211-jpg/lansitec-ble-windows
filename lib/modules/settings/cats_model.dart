import 'package:flutter/widgets.dart';

List<String> categories = ["All", "Dogs", "Cats", "Birds", "Fish", "Reptiles"];

class Cat {
  final Color color;
  final String name, location, sex, image, description;
  final double age, weight;
  final int distance;
  final bool fav;

  Cat({
    required this.color,
    required this.name,
    required this.location,
    required this.sex,
    required this.image,
    required this.description,
    required this.age,
    required this.weight,
    required this.distance,
    required this.fav,
  });
}

List<Cat> cats = [
  Cat(
    color: Color(0xffffd690),
    name: 'Sphynx1',
    location: 'New York, USA',
    sex: 'Male',
    image: 'assets/images/cat.png',
    description: 'desc',
    age: 2.1,
    weight: 4.5,
    distance: 5,
    fav: true,
  ),
  Cat(
    color: Color.fromARGB(255, 81, 175, 167),
    name: 'Sphynx2',
    location: 'New York, USA',
    sex: 'Male',
    image: 'assets/images/cat2.png',
    description: 'desc',
    age: 2.1,
    weight: 4.5,
    distance: 5,
    fav: false,
  ),
  Cat(
    color: Color.fromARGB(255, 72, 175, 85),
    name: 'Sphynx3',
    location: 'New York, USA',
    sex: 'Male',
    image: 'assets/images/cat3.png',
    description: 'desc',
    age: 2.1,
    weight: 4.5,
    distance: 5,
    fav: true,
  ),
];

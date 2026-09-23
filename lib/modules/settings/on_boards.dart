class OnBoards {
  final String text, image;
  OnBoards({required this.text, required this.image});
}

final List<OnBoards> onBoardData = [
  OnBoards(
    text: "Welcome to Flutter Blue, Let's shop!",
    image: "assets/images/onboard1.png",
  ),
  OnBoards(
    text: "We help people conect with stores.",
    image: "assets/images/onboard2.png",
  ),
  OnBoards(
    text: "We show the easy way to shop.",
    image: "assets/images/onboard3.png",
  ),
];

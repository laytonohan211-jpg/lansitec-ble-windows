class RemoteRequest {
  String name;

  RemoteRequest(this.name);

  Map<String, dynamic> toJson() {
    return {'name': name};
  }
}

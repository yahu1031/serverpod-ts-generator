import 'endpoint_param.dart';

class EndpointMethod {
  final String name;
  final List<EndpointParam> params;
  final String returnType;
  final bool isGetter;
  final String? staticValue;
  final String? docComment;
  EndpointMethod(this.name, this.params, this.returnType, {this.isGetter = false, this.staticValue, this.docComment});
}

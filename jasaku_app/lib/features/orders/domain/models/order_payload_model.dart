class OrderPayloadModel {
  final String customerId;
  final String providerId;
  final String serviceId;
  final String pricingTypeId;
  final int quantity;
  final String description;
  final String workDate;
  final String address;
  final double lat;
  final double lng;
  final List<String> attachments;

  OrderPayloadModel({
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.pricingTypeId,
    required this.quantity,
    required this.description,
    required this.workDate,
    required this.address,
    required this.lat,
    required this.lng,
    required this.attachments,
  });

  Map<String, dynamic> toJson() => {
    "customerId": customerId,
    "providerId": providerId,
    "serviceId": serviceId,
    "pricingTypeId": pricingTypeId,
    "quantity": quantity,
    "description": description,
    "workDate": workDate,
    "address": address,
    "lat": lat,
    "lng": lng,
    "attachments": attachments,
  };
}
namespace DwsimService.Models.Requests;

public record FlashRequest(
    List<string> Compounds,
    List<double> Composition,
    string PropertyPackage,
    double? Temperature,
    double? Pressure,
    double? Enthalpy,
    double? Entropy,
    double? VaporFraction
);

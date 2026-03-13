namespace DwsimService.Models.Requests;

public record ThermodynamicRequest(
    List<string> Compounds,
    List<double> Composition,
    string PropertyPackage,
    double Temperature,
    double Pressure
);

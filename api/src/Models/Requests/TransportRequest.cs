namespace DwsimService.Models.Requests;

public record TransportRequest(
    List<string> Compounds,
    List<double> Composition,
    string PropertyPackage,
    double Temperature,
    double Pressure
);

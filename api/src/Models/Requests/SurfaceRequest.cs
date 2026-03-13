namespace DwsimService.Models.Requests;

public record SurfaceRequest(
    List<string> Compounds,
    List<double> Composition,
    string PropertyPackage,
    double Temperature,
    double Pressure
);

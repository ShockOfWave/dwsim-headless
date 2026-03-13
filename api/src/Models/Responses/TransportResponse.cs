namespace DwsimService.Models.Responses;

public record TransportResponse(
    double Temperature,
    double Pressure,
    double? ViscosityLiquid,
    double? ViscosityVapor,
    double? ThermalConductivityLiquid,
    double? ThermalConductivityVapor,
    double? ThermalConductivityMixture
);

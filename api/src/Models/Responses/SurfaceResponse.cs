namespace DwsimService.Models.Responses;

public record SurfaceResponse(
    double Temperature,
    double Pressure,
    double? SurfaceTension
);

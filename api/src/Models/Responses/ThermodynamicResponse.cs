namespace DwsimService.Models.Responses;

public record ThermodynamicResponse(
    double Temperature,
    double Pressure,
    double? MolarVolume,
    double? Enthalpy,
    double? Entropy,
    double? GibbsEnergy,
    double? HeatCapacityCp,
    double? HeatCapacityCv,
    double? MolecularWeight,
    double? CompressibilityFactor,
    List<string> Phases
);

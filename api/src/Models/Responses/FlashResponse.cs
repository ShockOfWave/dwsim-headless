namespace DwsimService.Models.Responses;

public record PhaseResult(
    string PhaseName,
    double Fraction,
    Dictionary<string, double> Composition,
    double? Temperature,
    double? Pressure,
    double? Enthalpy,
    double? Entropy,
    double? MolarVolume
);

public record FlashResponse(
    double Temperature,
    double Pressure,
    double VaporFraction,
    List<PhaseResult> Phases,
    List<string> Errors
);

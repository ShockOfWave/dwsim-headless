namespace DwsimService.Models.Responses;

public record ErrorResponse(string Error, string? Detail = null);

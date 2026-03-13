using DwsimService.Services;

namespace DwsimService.Endpoints;

public static class VerifyCompoundsEndpoints
{
    public record VerifyRequest(List<string> Compounds);

    public record VerifyResult(string Name, string Status, List<string>? Candidates);

    public static void MapVerifyCompoundsEndpoints(this WebApplication app)
    {
        app.MapPost("/verify-compounds", async (VerifyRequest request, DwsimEnginePool pool, CancellationToken ct) =>
        {
            var results = await pool.ExecuteAsync(engine =>
            {
                var available = engine.GetAvailableCompounds();
                var availableSet = new HashSet<string>(available, StringComparer.OrdinalIgnoreCase);

                return request.Compounds.Select(name =>
                {
                    if (availableSet.Contains(name))
                    {
                        var exactName = available.First(a => a.Equals(name, StringComparison.OrdinalIgnoreCase));
                        return new VerifyResult(name, "found", new List<string> { exactName });
                    }

                    var candidates = available
                        .Where(a => a.Contains(name, StringComparison.OrdinalIgnoreCase))
                        .Take(10)
                        .ToList();

                    return candidates.Count > 0
                        ? new VerifyResult(name, "ambiguous", candidates)
                        : new VerifyResult(name, "not_found", null);
                }).ToList();
            }, ct);

            return Results.Ok(results);
        });
    }
}

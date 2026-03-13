using DwsimService.Models.Responses;
using DwsimService.Services;

namespace DwsimService.Endpoints;

public static class CompoundsEndpoints
{
    public static void MapCompoundsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("");

        group.MapGet("/compounds", async (DwsimEnginePool pool, CancellationToken ct) =>
            await pool.ExecuteAsync(engine =>
                engine.GetAvailableCompounds()
                    .Select(name => new CompoundInfo(name))
                    .ToList(),
                ct));

        group.MapGet("/compounds/search", async (string q, DwsimEnginePool pool, CancellationToken ct) =>
            await pool.ExecuteAsync(engine =>
                engine.GetAvailableCompounds()
                    .Where(name => name.Contains(q, StringComparison.OrdinalIgnoreCase))
                    .Select(name => new CompoundInfo(name))
                    .ToList(),
                ct));
    }
}

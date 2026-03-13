using DwsimService.Services;

namespace DwsimService.Endpoints;

public static class PropertyPackageEndpoints
{
    public static void MapPropertyPackageEndpoints(this WebApplication app)
    {
        app.MapGet("/property-packages", async (DwsimEnginePool pool, CancellationToken ct) =>
            await pool.ExecuteAsync(engine => engine.GetAvailablePropertyPackages(), ct));
    }
}

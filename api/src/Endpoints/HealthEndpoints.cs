using DwsimService.Services;

namespace DwsimService.Endpoints;

public static class HealthEndpoints
{
    public static void MapHealthEndpoints(this WebApplication app)
    {
        app.MapGet("/health", async (DwsimEnginePool pool, CancellationToken ct) =>
        {
            var result = await pool.ExecuteAsync(engine => new
            {
                status = "healthy",
                service = "dwsim",
                version = engine.GetVersion()
            }, ct);
            return Results.Ok(result);
        });
    }
}

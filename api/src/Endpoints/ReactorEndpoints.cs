using DwsimService.Models.Requests;
using DwsimService.Models.Responses;
using DwsimService.Services;

namespace DwsimService.Endpoints;

public static class ReactorEndpoints
{
    public static void MapReactorEndpoints(this WebApplication app)
    {
        app.MapPost("/reactor/simulate",
            async (ReactorSimulationRequest req, DwsimEnginePool pool, CancellationToken ct) =>
        {
            try
            {
                var result = await pool.ExecuteAsync(engine =>
                    ReactorSimulationService.Simulate(engine, req), ct);
                return Results.Ok(result);
            }
            catch (ArgumentException ex)
            {
                return Results.BadRequest(new ErrorResponse(ex.Message));
            }
            catch (Exception ex)
            {
                return Results.Json(
                    new ErrorResponse("Reactor simulation failed", ex.Message),
                    statusCode: 422);
            }
        });
    }
}

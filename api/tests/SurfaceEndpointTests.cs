using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DwsimService.Tests;

public class SurfaceEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public SurfaceEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CalculateSurface_WaterPR_ReturnsSurfaceTension()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            temperature = 300.0,
            pressure = 101325.0
        };

        var response = await _client.PostAsJsonAsync("properties/surface", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.GetProperty("temperature").GetDouble() > 0);
        Assert.True(root.GetProperty("pressure").GetDouble() > 0);
        Assert.True(root.TryGetProperty("surfaceTension", out _));
    }
}

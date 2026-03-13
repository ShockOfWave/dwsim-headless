using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DwsimService.Tests;

public class TransportEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public TransportEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CalculateTransport_WaterPR_ReturnsProperties()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            temperature = 300.0,
            pressure = 101325.0
        };

        var response = await _client.PostAsJsonAsync("properties/transport", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.GetProperty("temperature").GetDouble() > 0);
        Assert.True(root.GetProperty("pressure").GetDouble() > 0);
        // At 300K, 1atm water is liquid — expect liquid viscosity
        Assert.True(root.TryGetProperty("viscosityLiquid", out _));
        Assert.True(root.TryGetProperty("thermalConductivityLiquid", out _));
    }
}

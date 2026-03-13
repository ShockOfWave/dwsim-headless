using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DwsimService.Tests;

public class ThermodynamicEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ThermodynamicEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CalculateThermodynamic_WaterPR_ReturnsProperties()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            temperature = 373.15,
            pressure = 101325.0
        };

        var response = await _client.PostAsJsonAsync("properties/thermodynamic", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.GetProperty("temperature").GetDouble() > 0);
        Assert.True(root.GetProperty("pressure").GetDouble() > 0);
        Assert.True(root.TryGetProperty("enthalpy", out _));
        Assert.True(root.TryGetProperty("entropy", out _));
        Assert.True(root.TryGetProperty("heatCapacityCp", out _));
        Assert.True(root.TryGetProperty("phases", out var phases));
        Assert.True(phases.GetArrayLength() > 0);
    }

    [Fact]
    public async Task CalculateThermodynamic_BinaryMixture_ReturnsProperties()
    {
        var request = new
        {
            compounds = new[] { "Water", "Ethanol" },
            composition = new[] { 0.5, 0.5 },
            propertyPackage = "NRTL",
            temperature = 350.0,
            pressure = 101325.0
        };

        var response = await _client.PostAsJsonAsync("properties/thermodynamic", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.TryGetProperty("fugacity", out var fugacity));
        Assert.True(fugacity.TryGetProperty("Water", out _));
        Assert.True(fugacity.TryGetProperty("Ethanol", out _));
    }
}

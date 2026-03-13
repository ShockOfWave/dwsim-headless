using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DwsimService.Tests;

public class FlashEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public FlashEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task FlashPT_WaterAtBoiling_ReturnsVaporFraction()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            temperature = 373.15,
            pressure = 101325.0
        };

        var response = await _client.PostAsJsonAsync("flash/pt", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.TryGetProperty("vaporFraction", out _));
        Assert.True(root.TryGetProperty("phases", out var phases));
        Assert.True(phases.GetArrayLength() > 0);
    }

    [Fact]
    public async Task FlashPT_BinaryMixture_ReturnsTwoPhases()
    {
        var request = new
        {
            compounds = new[] { "Water", "Ethanol" },
            composition = new[] { 0.5, 0.5 },
            propertyPackage = "NRTL",
            temperature = 360.0,
            pressure = 101325.0
        };

        var response = await _client.PostAsJsonAsync("flash/pt", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var vf = root.GetProperty("vaporFraction").GetDouble();
        Assert.InRange(vf, 0.0, 1.0);
    }

    [Fact]
    public async Task FlashPH_Water_ReturnsResult()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            pressure = 101325.0,
            enthalpy = -13000.0
        };

        var response = await _client.PostAsJsonAsync("flash/ph", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.GetProperty("temperature").GetDouble() > 0);
    }

    [Fact]
    public async Task FlashPS_Water_ReturnsResult()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            pressure = 101325.0,
            entropy = -35.0
        };

        var response = await _client.PostAsJsonAsync("flash/ps", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task FlashTVF_Water_ReturnsBubblePoint()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            temperature = 373.15,
            vaporFraction = 0.0
        };

        var response = await _client.PostAsJsonAsync("flash/tvf", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        // Bubble point pressure should be around 101325 Pa
        Assert.True(root.GetProperty("pressure").GetDouble() > 50000);
    }

    [Fact]
    public async Task FlashPVF_Water_ReturnsDewPoint()
    {
        var request = new
        {
            compounds = new[] { "Water" },
            composition = new[] { 1.0 },
            propertyPackage = "Peng-Robinson (PR)",
            pressure = 101325.0,
            vaporFraction = 1.0
        };

        var response = await _client.PostAsJsonAsync("flash/pvf", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        // Dew point temperature should be around 373 K
        Assert.True(root.GetProperty("temperature").GetDouble() > 300);
    }
}

using Microsoft.AspNetCore.Mvc.Testing;

namespace DwsimService.Tests;

/// <summary>
/// Shared WebApplicationFactory for DWSIM API integration tests.
/// Requires DWSIM DLLs to be available (runs inside Docker).
/// </summary>
public class DwsimApiFixture : IClassFixture<WebApplicationFactory<Program>>
{
    protected readonly HttpClient Client;

    public DwsimApiFixture(WebApplicationFactory<Program> factory)
    {
        Client = factory.CreateClient();
    }
}

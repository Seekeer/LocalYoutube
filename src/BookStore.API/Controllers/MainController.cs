using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FileStore.API.Controllers
{
    [ApiController]
    [Authorize]
    public abstract class MainController : ControllerBase
    {

    }
}
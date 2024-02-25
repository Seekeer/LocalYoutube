using FileStore.Domain.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;

namespace FileStore.API.Controllers
{
    [ApiController]
    [Authorize]
    public abstract class MainController : ControllerBase
    {
        protected async Task<string> GetUserId(UserManager<ApplicationUser> userManager)
        {
            var user = await GetUser(userManager);
            return user.Id;
        }

        protected async Task<ApplicationUser> GetUser(UserManager<ApplicationUser> userManager)
        {
            var name = HttpContext.User.Claims.FirstOrDefault(x => x.Type == ClaimTypes.Name);
            var user = await userManager.FindByNameAsync(name.Value);
            return user;
        }
    }
}
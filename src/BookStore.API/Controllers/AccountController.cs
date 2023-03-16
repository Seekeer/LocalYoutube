using System;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Security.Claims;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using FileStore.API.JWT;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace FileStore.API.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/[controller]")]
    public class AccountController : ControllerBase
    {
        private readonly ILogger<AccountController> _logger;
        private readonly IJwtAuthManager _jwtAuthManager;
        private readonly VideoCatalogDbContext _dbContext;
        private readonly UserManager<ApplicationUser> _userManager;
        private static readonly string REFRESH_TOKEN_CLAIM_TYPE = ClaimTypes.Anonymous.ToString();

        public AccountController(ILogger<AccountController> logger, UserManager<ApplicationUser> userManager,  IJwtAuthManager jwtAuthManager,
            VideoCatalogDbContext dbContext)
        {
            _logger = logger;
            _jwtAuthManager = jwtAuthManager;

            _dbContext = dbContext;
            _userManager = userManager;
        }

        [AllowAnonymous]
        [HttpPost("login")]
        public async Task<ActionResult<LoginResult>> Login([FromBody] LoginRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest();
            }
            
            //var managedUser = await _userManager.FindByNameAsync(request.UserName);
            //_userManager.DeleteAsync(managedUser);
            var user = new ApplicationUser { UserName = request.UserName };
            var createdUser = await _userManager.CreateAsync(user, request.Password);

            var managedUser = await _userManager.FindByNameAsync(request.UserName);
            if (managedUser == null)
            {
                return BadRequest("Bad credentials");
            }
            var isPasswordValid = await _userManager.CheckPasswordAsync(managedUser, request.Password);
            if (!isPasswordValid)
            {
                return BadRequest("Bad credentials");
            }

            var userInDb = await _userManager.FindByNameAsync(request.UserName);
            if (userInDb is null)
                return Unauthorized();

            //var role = await _userManager.GetRolesAsync(userInDb);
            var claims = await _userManager.GetClaimsAsync(userInDb);

            var jwtResult = _jwtAuthManager.GenerateTokens(request.UserName, claims, DateTime.Now);
            await _UpdateUserRefreshToken(userInDb, jwtResult.RefreshToken, claims);

            _logger.LogInformation($"User [{request.UserName}] logged in the system.");

            return Ok(new LoginResult
            {
                UserName = request.UserName,
                //Role = role,
                AccessToken = jwtResult.AccessToken,
                RefreshToken = jwtResult.RefreshToken
            });
        }

        private async Task _UpdateUserRefreshToken(ApplicationUser userInDb, string refreshToken, 
            System.Collections.Generic.IList<Claim> claims)
        {
            await _userManager.AddClaimAsync(userInDb, new Claim(REFRESH_TOKEN_CLAIM_TYPE, refreshToken));

            await _userManager.RemoveClaimsAsync(userInDb, claims.Where(x => x.Type == ClaimTypes.Hash));
            await _userManager.AddClaimAsync(userInDb, new Claim(ClaimTypes.Hash, userInDb.Id));
        }

        [HttpGet("user")]
        [Authorize]
        public ActionResult GetCurrentUser()
        {
            return Ok(new LoginResult
            {
                UserName = User.Identity?.Name,
                Role = User.FindFirst(ClaimTypes.Role)?.Value ?? string.Empty,
                OriginalUserName = User.FindFirst("OriginalUserName")?.Value
            });
        }

        [HttpPost("logout")]
        [Authorize]
        public ActionResult Logout()
        {
            // optionally "revoke" JWT token on the server side --> add the current token to a block-list
            // https://github.com/auth0/node-jsonwebtoken/issues/375

            var userName = User.Identity?.Name;
            //_jwtAuthManager.RemoveRecfreshTokenByUserName(userName);
            _logger.LogInformation($"User [{userName}] logged out the system.");
            return Ok();
        }

        [HttpPost("refresh-token")]
        [Authorize]
        public async Task<ActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.UserName))
                {
                    return Unauthorized();
                }

                var managedUser = await _userManager.FindByNameAsync(request.UserName);
                var claims = await _userManager.GetClaimsAsync(managedUser);

                _logger.LogInformation($"User [{request.UserName}] is trying to refresh JWT token.");

                if (string.IsNullOrWhiteSpace(request.RefreshToken))
                {
                    return Unauthorized();
                }

                var accessToken = await HttpContext.GetTokenAsync("Bearer", "access_token");
                var jwtResult = _jwtAuthManager.Refresh(request.RefreshToken, accessToken, DateTime.Now, claims);
                await _UpdateUserRefreshToken(managedUser, jwtResult.RefreshToken, claims);
                _logger.LogInformation($"User [{request.UserName}] has refreshed JWT token.");
                return Ok(new LoginResult
                {
                    UserName = request.UserName,
                    Role = User.FindFirst(ClaimTypes.Role)?.Value ?? string.Empty,
                    AccessToken = jwtResult.AccessToken,
                    RefreshToken = jwtResult.RefreshToken
                });
            }
            catch (SecurityTokenException e)
            {
                return Unauthorized(e.Message); // return 401 so that the client side can redirect the user to login page
            }
        }

        //    [HttpPost("impersonation")]
        //    [Authorize(Roles = UserRoles.Admin)]
        //    public ActionResult Impersonate([FromBody] ImpersonationRequest request)
        //    {
        //        var userName = User.Identity?.Name;
        //        _logger.LogInformation($"User [{userName}] is trying to impersonate [{request.UserName}].");

        //        var impersonatedRole = _userService.GetUserRole(request.UserName);
        //        if (string.IsNullOrWhiteSpace(impersonatedRole))
        //        {
        //            _logger.LogInformation($"User [{userName}] failed to impersonate [{request.UserName}] due to the target user not found.");
        //            return BadRequest($"The target user [{request.UserName}] is not found.");
        //        }
        //        if (impersonatedRole == UserRoles.Admin)
        //        {
        //            _logger.LogInformation($"User [{userName}] is not allowed to impersonate another Admin.");
        //            return BadRequest("This action is not supported.");
        //        }

        //        var claims = new[]
        //        {
        //            new Claim(ClaimTypes.Name,request.UserName),
        //            new Claim(ClaimTypes.Role, impersonatedRole),
        //            new Claim("OriginalUserName", userName ?? string.Empty)
        //        };

        //        var jwtResult = _jwtAuthManager.GenerateTokens(request.UserName, claims, DateTime.Now);
        //        _logger.LogInformation($"User [{request.UserName}] is impersonating [{request.UserName}] in the system.");
        //        return Ok(new LoginResult
        //        {
        //            UserName = request.UserName,
        //            Role = impersonatedRole,
        //            OriginalUserName = userName,
        //            AccessToken = jwtResult.AccessToken,
        //            RefreshToken = jwtResult.RefreshToken
        //        });
        //    }

        //    [HttpPost("stop-impersonation")]
        //    public ActionResult StopImpersonation()
        //    {
        //        var userName = User.Identity?.Name;
        //        var originalUserName = User.FindFirst("OriginalUserName")?.Value;
        //        if (string.IsNullOrWhiteSpace(originalUserName))
        //        {
        //            return BadRequest("You are not impersonating anyone.");
        //        }
        //        _logger.LogInformation($"User [{originalUserName}] is trying to stop impersonate [{userName}].");

        //        var role = _userService.GetUserRole(originalUserName);
        //        var claims = new[]
        //        {
        //            new Claim(ClaimTypes.Name,originalUserName),
        //            new Claim(ClaimTypes.Role, role)
        //        };

        //        var jwtResult = _jwtAuthManager.GenerateTokens(originalUserName, claims, DateTime.Now);
        //        _logger.LogInformation($"User [{originalUserName}] has stopped impersonation.");
        //        return Ok(new LoginResult
        //        {
        //            UserName = originalUserName,
        //            Role = role,
        //            OriginalUserName = null,
        //            AccessToken = jwtResult.AccessToken,
        //            RefreshToken = jwtResult.RefreshToken
        //        });
        //    }
    }

    public class LoginRequest
    {
        [Required]
        [JsonPropertyName("username")]
        public string UserName { get; set; }

        [Required]
        [JsonPropertyName("password")]
        public string Password { get; set; }
    }

    public class LoginResult
    {
        [JsonPropertyName("username")]
        public string UserName { get; set; }

        [JsonPropertyName("role")]
        public string Role { get; set; }

        [JsonPropertyName("originalUserName")]
        public string OriginalUserName { get; set; }

        [JsonPropertyName("accessToken")]
        public string AccessToken { get; set; }

        [JsonPropertyName("refreshToken")]
        public string RefreshToken { get; set; }
    }

    public class RefreshTokenRequest
    {
        [JsonPropertyName("refreshToken")]
        public string RefreshToken { get; set; }
        [JsonPropertyName("userName")]
        public string UserName { get; set; }
    }

    public class ImpersonationRequest
    {
        [JsonPropertyName("username")]
        public string UserName { get; set; }
    }
}

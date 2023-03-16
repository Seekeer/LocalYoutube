using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using FileStore.Infrastructure.Context;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using YoutubeExplode.Channels;

namespace FileStore.API.JWT
{
    public interface IJwtAuthManager
    {
        JwtAuthResult GenerateTokens(string username, IEnumerable<Claim> claims, DateTime now);
        JwtAuthResult Refresh(string refreshToken, string accessToken, DateTime now, IEnumerable<Claim> claims);
        void RemoveExpiredRefreshTokens(DateTime now);
        //void RemoveRefreshTokenByUserName(string userName);
        (ClaimsPrincipal, JwtSecurityToken) DecodeJwtToken(string token);
    }

    public class JwtAuthManager : IJwtAuthManager
    {
        private readonly JwtTokenConfig _jwtTokenConfig;
        private readonly byte[] _secret;

        public JwtAuthManager(JwtTokenConfig jwtTokenConfig)
        {
            _jwtTokenConfig = jwtTokenConfig;
            _secret = Encoding.ASCII.GetBytes(jwtTokenConfig.Secret);
        }

        // TODO auth
        //// optional: clean up expired refresh tokens
        public void RemoveExpiredRefreshTokens(DateTime now)
        {
            //var expiredTokens = _usersRefreshTokens.Where(x => x.Value.ExpireAt < now).ToList();
            //foreach (var expiredToken in expiredTokens)
            //{
            //    _usersRefreshTokens.TryRemove(expiredToken.Key, out _);
            //}
        }

        // TODO auth
        // can be more specific to ip, user agent, device name, etc.
        //public void RemoveRefreshTokenByUserName(string userName)
        //{
        //    var refreshTokens = _usersRefreshTokens.Where(x => x.Value.UserName == userName).ToList();
        //    foreach (var refreshToken in refreshTokens)
        //    {
        //        _usersRefreshTokens.TryRemove(refreshToken.Key, out _);
        //    }
        //}

        public JwtAuthResult GenerateTokens(string username, IEnumerable<Claim> claims, DateTime now)
        {
            var shouldAddAudienceClaim = string.IsNullOrWhiteSpace(claims?.FirstOrDefault(x => x.Type == JwtRegisteredClaimNames.Aud)?.Value);
            var jwtToken = new JwtSecurityToken(
                _jwtTokenConfig.Issuer,
                shouldAddAudienceClaim ? _jwtTokenConfig.Audience : string.Empty,
                claims,
                expires: now.AddMinutes(_jwtTokenConfig.AccessTokenExpiration),
                signingCredentials: new SigningCredentials(new SymmetricSecurityKey(_secret), SecurityAlgorithms.HmacSha256Signature));
            var accessToken = new JwtSecurityTokenHandler().WriteToken(jwtToken);

            //var refreshToken = new RefreshToken
            //{
            //    UserName = username,
            var tokenString = GenerateRefreshTokenString();
            var expireAt = now.AddMinutes(_jwtTokenConfig.RefreshTokenExpiration);
            //};

            //var user = _db.Users.First(x => x.UserName == username);
            //user.add
            //user.TokenString = tokenString;
            //user.ExpireAt = expireAt;
            //_db.SaveChanges();

            return new JwtAuthResult
            {
                AccessToken = accessToken,
                RefreshToken = tokenString
            };
        }

        public JwtAuthResult Refresh(string refreshToken, string accessToken, DateTime now, IEnumerable<Claim> claims)
        {
            var (principal, jwtToken) = DecodeJwtToken(accessToken);
            if (jwtToken == null || !jwtToken.Header.Alg.Equals(SecurityAlgorithms.HmacSha256Signature))
            {
                throw new SecurityTokenException("Invalid token");
            }

            var userName = principal.Identity?.Name;

            //var user = _db.Users.FirstOrDefault(x => x.UserName == userName);
            if (!claims.Any(x => x.Type == ClaimTypes.Anonymous && x.Value == refreshToken))
            {
                throw new SecurityTokenException("Invalid token");
            }
            // TODO auth expire
            //if (existingRefreshToken.UserName != userName || existingRefreshToken.ExpireAt < now)
            //{
            //    throw new SecurityTokenException("Invalid token");
            //}

            return GenerateTokens(userName, principal.Claims.ToArray(), now); 
        }

        public (ClaimsPrincipal, JwtSecurityToken) DecodeJwtToken(string token)
        {
            if (string.IsNullOrWhiteSpace(token))
            {
                throw new SecurityTokenException("Invalid token");
            }
            var principal = new JwtSecurityTokenHandler()
                .ValidateToken(token,
                    new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = _jwtTokenConfig.Issuer,
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = new SymmetricSecurityKey(_secret),
                        ValidAudience = _jwtTokenConfig.Audience,
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        ClockSkew = TimeSpan.FromMinutes(1)
                    },
                    out var validatedToken);
            return (principal, validatedToken as JwtSecurityToken);
        }

        private static string GenerateRefreshTokenString()
        {
            var randomNumber = new byte[32];
            using var randomNumberGenerator = RandomNumberGenerator.Create();
            randomNumberGenerator.GetBytes(randomNumber);
            return Convert.ToBase64String(randomNumber);
        }
    }

    public class JwtAuthResult
    {
        [JsonPropertyName("accessToken")]
        public string AccessToken { get; set; }

        [JsonPropertyName("refreshToken")]
        public string RefreshToken { get; set; }
    }

    //public class RefreshToken
    //{
    //    [JsonPropertyName("username")]
    //    public string UserName { get; set; }    // can be used for usage tracking
    //    // can optionally include other metadata, such as user agent, ip address, device name, and so on

    //    [JsonPropertyName("tokenString")]
    //    public string TokenString { get; set; }

    //    [JsonPropertyName("expireAt")]
    //    public DateTime ExpireAt { get; set; }
    //}
}

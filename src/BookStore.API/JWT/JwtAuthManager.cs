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
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using YoutubeExplode.Channels;

namespace FileStore.API.JWT
{
    public interface IJwtAuthManager
    {
        JwtAuthResult GenerateTokens(IEnumerable<Claim> claims, DateTime now, string userId, string refreshToken = null);
        JwtAuthResult Refresh(string refreshToken, string accessToken, DateTime now, IEnumerable<Claim> claims);
        void RemoveExpiredRefreshTokens(DateTime now);
        //void RemoveRefreshTokenByUserName(string userName);
        (ClaimsPrincipal, JwtSecurityToken) DecodeJwtToken(string token);
    }

    public class TokenGenerator
    {
        public string Generate(string secretKey, string issuer, string audience, double expires, IEnumerable<Claim> claims = null)
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
            JwtSecurityToken securityToken = new(issuer, audience,
                claims,
                DateTime.UtcNow,
                DateTime.UtcNow.AddMinutes(expires),
                credentials);
            return new JwtSecurityTokenHandler().WriteToken(securityToken);
        }
    }

    public class JwtAuthManager : IJwtAuthManager
    {
        private readonly VideoCatalogDbContext _db;
        private readonly JwtTokenConfig _jwtTokenConfig;
        private readonly byte[] _secret;

        public JwtAuthManager(JwtTokenConfig jwtTokenConfig, VideoCatalogDbContext db)
        {
            _db = db;
            _jwtTokenConfig = jwtTokenConfig;
            _secret = Encoding.ASCII.GetBytes(jwtTokenConfig.Secret);
        }

        // TODO auth
        //// optional: clean up expired refresh tokens
        public void RemoveExpiredRefreshTokens(DateTime now)
        {
            //var expiredTokens = _usersRefreshTokens.Where(x => x.PLAYLIST_NAME.ExpireAt < now).ToList();
            //foreach (var expiredToken in expiredTokens)
            //{
            //    _usersRefreshTokens.TryRemove(expiredToken.Key, out _);
            //}
        }

        // TODO auth
        // can be more specific to ip, user agent, device name, etc.
        //public void RemoveRefreshTokenByUserName(string userName)
        //{
        //    var refreshTokens = _usersRefreshTokens.Where(x => x.PLAYLIST_NAME.UserName == userName).ToList();
        //    foreach (var refreshToken in refreshTokens)
        //    {
        //        _usersRefreshTokens.TryRemove(refreshToken.Key, out _);
        //    }
        //}

        public JwtAuthResult GenerateTokens(IEnumerable<Claim> claims, DateTime now, string userId, string refreshToken = null)
        {
            var shouldAddAudienceClaim = string.IsNullOrWhiteSpace(claims?.FirstOrDefault(x => x.Type == JwtRegisteredClaimNames.Aud)?.Value);
            var jwtToken = new JwtSecurityToken(
                _jwtTokenConfig.Issuer,
                shouldAddAudienceClaim ? _jwtTokenConfig.Audience : string.Empty,
                claims,
                expires: now.AddMinutes(_jwtTokenConfig.AccessTokenExpiration),
                signingCredentials: new SigningCredentials(new SymmetricSecurityKey(_secret), SecurityAlgorithms.HmacSha256Signature));
            var accessToken = new JwtSecurityTokenHandler().WriteToken(jwtToken);

            if (string.IsNullOrEmpty(refreshToken))
            {
                refreshToken = (new TokenGenerator()).Generate(_jwtTokenConfig.Secret, _jwtTokenConfig.Issuer, _jwtTokenConfig.Audience,
                    _jwtTokenConfig.AccessTokenExpiration, claims);

                var token = new UserRefreshTokens
                {
                    UserName = userId,
                    RefreshToken = refreshToken,
                    IsActive = true
                };
                _db.RefreshTokens.Add(token);
                _db.SaveChanges();
            }

            return new JwtAuthResult
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken
            };
        }

        public JwtAuthResult Refresh(string refreshToken, string accessToken, DateTime now, IEnumerable<Claim> claims)
        {
            var (principal, jwtToken) = DecodeJwtToken(accessToken);
            if (jwtToken == null || !jwtToken.Header.Alg.Equals(SecurityAlgorithms.HmacSha256Signature))
            {
                throw new SecurityTokenException("Invalid token");
            }

            var refreshTokens = _db.RefreshTokens.Where(x =>x.RefreshToken == refreshToken).ToList();

            if(refreshToken == null)
                throw new SecurityTokenException("Invalid token");

            // TODO auth expire
            //if (existingRefreshToken.UserName != userName || existingRefreshToken.ExpireAt < now)
            //{
            //    throw new SecurityTokenException("Invalid token");
            //}

            return GenerateTokens(principal.Claims.ToArray(), now, null, refreshToken); 
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

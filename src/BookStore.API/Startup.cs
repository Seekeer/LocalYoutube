using API.FilmDownload;
using AutoMapper;
using FileStore.API.Configuration;
using FileStore.Infrastructure.Context;
using Hangfire;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http.Extensions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;
using System;
using System.Net.Http;
using System.Timers;

namespace FileStore.API
{

    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        private readonly string _policyName = "CorsPolicy";
        private Timer _aTimer;

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddDbContext<VideoCatalogDbContext>(options =>
            {
                options.UseSqlServer(Configuration.GetConnectionString("DefaultConnection"));
            });

            services.AddAutoMapper(typeof(Startup));

            services.AddCors(opt =>
            {
                opt.AddPolicy(name: _policyName, builder =>
                {
                    builder.AllowAnyOrigin()
                        .AllowAnyHeader()
                        .AllowAnyMethod();
                });
            });
            services.AddControllers();

            services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new OpenApiInfo()
                {
                    Title = "BookStore API",
                    Version = "v1"
                });
            });

            //services.AddCors();

            var cfg = Configuration.Get<AppConfig>();
            services.AddSingleton<AppConfig>(cfg);

            services.ResolveDependencies();

        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            app.Use((context, next) =>
            {
                var url = context.Request.GetDisplayUrl();
                var uri = new Uri(url);
                var builder = new UriBuilder(uri);
                builder.Path = "api/update/stub";

                if(_aTimer == null)
                {
                    _aTimer = new System.Timers.Timer();
                    _aTimer.Elapsed += (_, __) => { new HttpClient().GetAsync(builder.ToString()); };
                    _aTimer.Interval = TimeSpan.FromSeconds(30).TotalMilliseconds;
                    _aTimer.Enabled = true;
                }
                //RecurringJob.AddOrUpdate(() => new HttpClient().GetAsync(builder.ToString()), " */4 * * * *");

                return next.Invoke();
            });

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "v1");
            });

            //app.UseHttpsRedirection();

            app.UseRouting();

            app.UseCors(_policyName);
            app.UseAuthorization();

            //app.UseCors(x => x.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });

        }
    }
}

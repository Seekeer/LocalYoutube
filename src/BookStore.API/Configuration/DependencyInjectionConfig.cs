using FileStore.Domain.Interfaces;
using FileStore.Domain.Services;
using FileStore.Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using Microsoft.Extensions.DependencyInjection;

namespace FileStore.API.Configuration
{
    public static class DependencyInjectionConfig
    {
        public static IServiceCollection ResolveDependencies(this IServiceCollection services)
        {
            services.AddScoped<VideoCatalogDbContext>();

            services.AddScoped<ISeriesRepository, SeriesRepository>();
            services.AddScoped<IFileRepository, FileRepository>();

            services.AddScoped<ISeriesService, SeriesService>();
            services.AddScoped<IFileService, FileService>();

            return services;
        }
    }
}
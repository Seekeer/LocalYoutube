using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using Infrastructure.Context;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;

namespace Infrastructure.Context
{

    public interface IFilePathProvider
    {
        string GetFilePath();
    }

    public class DesignTimePathProvider : IFilePathProvider
    {
        public string GetFilePath()
        {
            return "DesignTime.db";
        }
    }

    public class DbContextMigrationFactory : IDesignTimeDbContextFactory<MAUIDbContext>
    {
        private readonly IFilePathProvider dbPathProvider;

        public DbContextMigrationFactory() : this(new DesignTimePathProvider())
        {
        }

        private DbContextMigrationFactory(IFilePathProvider filePathProvider)
        {
            this.dbPathProvider = filePathProvider;
        }

        public MAUIDbContext CreateDbContext(string[] args)
        {
            var builder = new DbContextOptionsBuilder<MAUIDbContext>();

            var dbPath = dbPathProvider.GetFilePath();
            // This filename can be anything
            builder.UseSqlite($"FileName={dbPath}");

            return new MAUIDbContext(builder.Options);
        }
    }

    // PM> cd .\src\BookStore.Infrastructure\
    // PM> dotnet ef migrations add InitialCreate --context MAUIDbContext --output-dir MigrationsSqlite
    public class MAUIDbContext : VideoCatalogDbContext
    {
        public MAUIDbContext(DbContextOptions options) : base(options) { }
    }
}

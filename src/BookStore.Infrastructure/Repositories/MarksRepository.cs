using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FileStore.Infrastructure.Repositories
{

    public interface IMarksRepository : IRepository<FileMark>
    {
    }

    public class MarksRepository : Repository<FileMark>, IMarksRepository
    {
        public MarksRepository(VideoCatalogDbContext context) : base(context) { }

    }

}
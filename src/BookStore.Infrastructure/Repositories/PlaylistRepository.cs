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

    public interface IPlaylistRepository : IRepository<Playlist>
    {
        Task<bool> AddToListAsync(int listId, int fileId);
        Task<bool> RemoveFromListAsync(int listId, int fileId);
    }

    public class PlaylistRepository : Repository<Playlist>, IPlaylistRepository
    {
        public PlaylistRepository(VideoCatalogDbContext context) : base(context) { }

        public override async Task<Playlist> GetById(int listId)
        {
            return await DbSet.Include(x => x.Files).FirstOrDefaultAsync(x => x.Id == listId);
        }

        public async Task<bool> AddToListAsync(int listId, int fileId)
        {
            var list = await GetById(listId);
            if (list == null)
                return false;

            if (list.Files.Any(x => x.Id == fileId))
                return false;

            var file = await Db.Files.FirstOrDefaultAsync(x => x.Id == fileId);
            if (file == null)
                return false;

            list.Files.Add(file);
            await Db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> RemoveFromListAsync(int listId, int fileId)
        {
            var list = await GetById(listId);
            if (list == null)
                return false;

            var file = list.Files.FirstOrDefault(x => x.Id == fileId);
            if (file == null)
                return false;
            else
                list.Files.Remove(file);  
            await Db.SaveChangesAsync();
            return true;
        }

        public async Task AddToFavorite(string userName, int fileId) 
        {
            var favorite = await this.FindByQueryAsync(x => x.Name == $"Избранное {userName}");
        }
    }
}
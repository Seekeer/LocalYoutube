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

    public class PlaylistRepository : Repository<Playlist>, IPlaylistRepository, tem
    {
        public PlaylistRepository(VideoCatalogDbContext context) : base(context) { }

        public override async Task<Playlist> GetById(int listId)
        {
            return await DbSet.Include(x => x.Items).ThenInclude(x => x.File).FirstOrDefaultAsync(x => x.Id == listId);
        }

        public async Task<bool> AddToListAsync(int listId, int fileId)
        {
            var list = await GetById(listId);
            if (list == null)
                return false;

            if (list.Items.Any(x => x.File.Id == fileId))
                return false;

            var file = await Db.Files.FirstOrDefaultAsync(x => x.Id == fileId);
            if (file == null)
                return false;

            list.Items.Add(new PlaylistItem { File = file, Index = list.Items.Count + 1 });
            await Db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> RemoveFromListAsync(int listId, int fileId)
        {
            var list = await GetById(listId);
            if (list == null)
                return false;

            var item = list.Items.FirstOrDefault(x => x.File.Id == fileId);

            if (item == null)
                return false;
            else
                list.Items.Remove(item);
            await Db.SaveChangesAsync();
            return true;
        }

        public async Task AddToFavorite(string userName, int fileId)
        {
            var favorite = await this.FindByQueryAsync(x => x.Name == $"Избранное {userName}");
        }
    }
}
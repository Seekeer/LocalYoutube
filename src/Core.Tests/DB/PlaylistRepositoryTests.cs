using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Repositories;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace Core.Tests.DB
{
    internal class PlaylistRepositoryTests : DBTest
    {
        [Test]
        public async Task WriteTest()
        {
            //(VideoFile file, Playlist playlist) = await CreateFileAndPlaylist();

            //var adddedPlaylist = await serviceProvider.GetService<PlaylistRepository>().GetById(playlist.Id);

            var repo = serviceProvider.GetService<IPlaylistRepository>();
            await repo.AddToListAsync(1,1);

            var adddedPlaylist = await repo.GetById(1);

            Assert.IsNotEmpty(adddedPlaylist.Items);
            Assert.AreEqual(1, adddedPlaylist.Items.First().File.Id);
        }

        [Test]
        public async Task RemoveTest()
        {
            var repo = serviceProvider.GetService<IPlaylistRepository>();
            await repo.AddToListAsync(1,1);

            var playList = await repo.GetById(1);
            Assert.IsNotEmpty(playList.Items);

            await repo.RemoveFromListAsync(1, 1);

            playList = await repo.GetById(1);
            Assert.IsEmpty(playList.Items);
        }
    }
}

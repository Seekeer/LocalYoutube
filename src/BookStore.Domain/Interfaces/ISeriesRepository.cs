using FileStore.Domain.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace FileStore.Domain.Interfaces
{
    public interface ISeriesRepository : IRepository<Series>
    {

        Task<IEnumerable<VideoFile>> SearchFileWithSeries(string searchedValue, int resultCount);
    }
}
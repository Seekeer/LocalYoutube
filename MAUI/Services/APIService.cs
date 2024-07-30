using Dtos;
using FileStore.Domain.Dtos;
using MAUI.ViewModels;

namespace MAUI.Services
{
    public interface IAPIService
    {
        Task<IEnumerable<VideoFileResultDtoDownloaded>> GetHistoryAsync();
        Task<IEnumerable<VideoFileResultDtoDownloaded>> GetFreshAsync();
        Task<PositionDTO> GetPositionAsync(int id);
        Task SetPositionAsync(int id, PositionDTO positionDTO);
    }

    public class APIService : IAPIService
    {
        private readonly HttpClientAuth _httpClientAuth;

        public APIService(HttpClientAuth httpClientAuth) {
            _httpClientAuth = httpClientAuth;
        }

        public static string GetCoverUrlForFile(string fileid)
        {
            return $"{HttpClientAuth.BASE_API_URL}Files/getImage?fileId={fileid}";
        }

        public async Task<PositionDTO> GetPositionAsync(int id)
        {
            var list = await _httpClientAuth.GetAsync<PositionDTO>($"files/getPositionMaui/{id}");
            return list;
        }

        public async Task SetPositionAsync(int id, PositionDTO positionDTO)
        {
            try
            {
                await _httpClientAuth.Put($"files/setPositionMaui/{id}", positionDTO);
            }
            catch (Exception ex)
            {
            }
        }

        public async Task<IEnumerable<VideoFileResultDtoDownloaded>> GetFreshAsync()
        {
            try
            {
                var list = await _httpClientAuth.GetAsync<IEnumerable<VideoFileResultDtoDownloaded>>($"files/getNew");
                return list;
            }
            catch (Exception ex)
            {
                return new List<VideoFileResultDtoDownloaded>();
            }
        }

        public async Task LogoutAsync()
        {
            HttpClientAuth.ClearTokens();
        }

        public async Task<IEnumerable<VideoFileResultDtoDownloaded>> GetHistoryAsync()
        {
            try
            { 
                var list = await _httpClientAuth.GetAsync<IEnumerable<VideoFileResultDtoDownloaded>>($"files/getLatest");
                return list;
            }
            catch (Exception ex)
            {
                return new List<VideoFileResultDtoDownloaded>();
            }

    //TODO no network
    //var list1 = new List<VideoFileResultDto>
    //{
    //    new VideoFileResultDto
    //    {
    //        CoverURL = "https://60.img.avito.st/image/1/1.e2WiAra414yUqxWJ2Gc0S8ag1Yoco1WE1KbVjhKr34YU.X0s5Dlazk8TBFZ-ZiyhhavQCV88ptt5n4-nzxyrEPOM",
    //        Name = "Мое видео",
    //        Description = "Описание",
    //        Id = 55664
    //    }
    //};
    //return list1;
}
    }
}

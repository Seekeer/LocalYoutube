using Dtos;
using FileStore.Domain.Dtos;

namespace MAUI.Services
{
    public interface IAPIService
    {
        Task<IEnumerable<VideoFileResultDto>> GetHistoryAsync();
        Task<IEnumerable<VideoFileResultDto>> GetFreshAsync();
        Task<PositionDTO> GetPositionAsync(int id);
        Task SetPositionAsync(int id, PositionDTO positionDTO);
    }

    public class APIService : IAPIService
    {
        private readonly HttpClientAuth _httpClientAuth;

        public APIService(HttpClientAuth httpClientAuth) {
            _httpClientAuth = httpClientAuth;
        }

        public async Task<PositionDTO> GetPositionAsync(int id)
        {
            var list = await _httpClientAuth.GetAsync<PositionDTO>($"files/getPositionMaui/{id}");
            return list;
        }

        public async Task SetPositionAsync(int id, PositionDTO positionDTO)
        {
            await _httpClientAuth.Put<string>($"files/setPositionMaui/{id}", positionDTO);
        }

        
        public async Task<IEnumerable<VideoFileResultDto>> GetFreshAsync()
        {
            var list = await _httpClientAuth.GetAsync<IEnumerable<VideoFileResultDto>>($"files/getNew");
            return list;
        }

        public async Task<IEnumerable<VideoFileResultDto>> GetHistoryAsync()
        {
            var list = await _httpClientAuth.GetAsync<IEnumerable<VideoFileResultDto>>($"files/getLatest");
            return list;

            //TODO no network
            var list1 = new List<VideoFileResultDto>
            {
                new VideoFileResultDto
                {
                    CoverURL = "https://60.img.avito.st/image/1/1.e2WiAra414yUqxWJ2Gc0S8ag1Yoco1WE1KbVjhKr34YU.X0s5Dlazk8TBFZ-ZiyhhavQCV88ptt5n4-nzxyrEPOM",
                    Name = "Мое видео",
                    Description = "Описание",
                    Id = 55664
                }
            };
            return list1;
        }
    }
}

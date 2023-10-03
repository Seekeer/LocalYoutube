namespace FileStore.API.Dtos.Series
{
    public class MarkAddDto
    {
        public int DbFileId { get; set; }
        public int Id { get; set; }
        //public int FileId { get; set; }
        //public string UserId { get; set; }
        public double Position { get; set; }
    }
}
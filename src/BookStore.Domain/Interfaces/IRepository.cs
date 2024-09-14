using System;
using System.Collections.Generic;
using System.Linq.Expressions;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IRepository<TEntity> : IDisposable where TEntity : Entity
    {
        Task<TEntity> AddAsync(TEntity entity);
        Task<List<TEntity>> GetAll();
        Task<TEntity> GetById(int id);
        Task UpdateAsync(TEntity entity);
        Task Remove(TEntity entity);
        Task Remove(int id);
        Task<IEnumerable<TEntity>> SearchRandom(Expression<Func<TEntity, bool>> predicate, int resultCount = 10);
        Task<int> SaveChangesAsync();
        Task<IEnumerable<TEntity>> SearchAsync(Expression<Func<TEntity, bool>> predicate);
        Task<TEntity> FindByQueryAsync(Expression<Func<TEntity, bool>> predicate);
    }
}
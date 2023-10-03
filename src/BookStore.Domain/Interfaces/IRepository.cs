using System;
using System.Collections.Generic;
using System.Linq.Expressions;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IRepository<TEntity> : IDisposable where TEntity : Entity
    {
        Task Add(TEntity entity);
        Task<List<TEntity>> GetAll();
        Task<TEntity> GetById(int id);
        Task Update(TEntity entity);
        Task Remove(TEntity entity);
        Task Remove(int id);
        Task<IEnumerable<TEntity>> SearchRandom(Expression<Func<TEntity, bool>> predicate, int resultCount = 10);
        Task<int> SaveChanges();
        Task<IEnumerable<TEntity>> Search(Expression<Func<TEntity, bool>> predicate);
    }
}
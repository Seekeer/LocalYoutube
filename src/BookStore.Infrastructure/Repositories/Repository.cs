using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace FileStore.Infrastructure.Repositories
{
    public abstract class Repository<TEntity> : IRepository<TEntity> where TEntity : Entity
    {
        protected readonly VideoCatalogDbContext Db;

        protected readonly DbSet<TEntity> DbSet;

        protected Repository(VideoCatalogDbContext db)
        {
            Db = db;
            DbSet = db.Set<TEntity>();
        }

        public virtual async Task<TEntity> AddAsync(TEntity entity)
        {
            DbSet.Add(entity);
            await SaveChangesAsync();

            return entity;
        }

        public virtual async Task<List<TEntity>> GetAll()
        {
            return await DbSet.ToListAsync();
        }

        public virtual async Task<TEntity> GetById(int id)
        {
            return await DbSet.FindAsync(id);
        }
        
        public virtual async Task UpdateAsync(TEntity entity)
        {
            DbSet.Update(entity);
            await SaveChangesAsync();
        }

        public virtual async Task Remove(TEntity entity)
        {
            DbSet.Remove(entity);
            await SaveChangesAsync();
        }

        public virtual async Task Remove(int entityId)
        {
            var entity= await GetById(entityId);
            await Remove(entity);
        }

        public async Task<IEnumerable<TEntity>> SearchRandom(Expression<Func<TEntity, bool>> predicate, int resultCount = 10)
        {
            return await Random(DbSet.AsNoTracking().Where(predicate), resultCount).ToListAsync();
        }

        public async Task<IEnumerable<TEntity>> SearchAsync(Expression<Func<TEntity, bool>> predicate)
        {
            return await (DbSet.AsNoTracking().Where(predicate).OrderBy(x => x.Id).ToListAsync());
        }

        public async Task<int> SaveChangesAsync()
        {
            return await Db.SaveChangesAsync();
        }

        public void Dispose()
        {
            Db?.Dispose();
        }

        protected IQueryable<T> Random<T>(IQueryable<T> query, int resultCount) 
        {
            if (resultCount > 0)
                return query.OrderBy(o => Guid.NewGuid()).Take(resultCount);
            else
                return query.OrderBy(o => Guid.NewGuid());
        }

        public async Task<TEntity> FindByQueryAsync(Expression<Func<TEntity, bool>> predicate)
        {
            return await DbSet.AsNoTracking().FirstOrDefaultAsync(predicate);
        }
    }
}
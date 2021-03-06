//using System.Collections.Generic;
//using System.Linq;
//using BookStore.Domain.Models;
//using BookStore.Infrastructure.Context;
//using BookStore.Infrastructure.Repositories;
//using Microsoft.EntityFrameworkCore;
//using Xunit;

//namespace BookStore.Infrastructure.Tests
//{
//    /// <summary>
//    /// This is another example of how to create tests for the abstract base class
//    /// </summary>
//    public class RepositoryTests
//    {
//        private readonly DbContextOptions<VideoCatalogDbContext> _options;

//        public RepositoryTests()
//        {
//            _options = BookStoreHelperTests.BookStoreDbContextOptionsSQLiteInMemory();
//            BookStoreHelperTests.CreateDataBaseSQLiteInMemory(_options);
//        }

//        [Fact]
//        public async void GetAll_ShouldReturnAListOfCategory_WhenCategoriesExist()
//        {
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);

//                var categories = await repository.GetAll();

//                Assert.NotNull(categories);
//                Assert.IsType<List<Season>>(categories);
//            }
//        }

//        [Fact]
//        public async void GetAll_ShouldReturnAnEmptyList_WhenCategoriesDoNotExist()
//        {
//            await BookStoreHelperTests.CleanDataBase(_options);

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);
//                var categories = await repository.GetAll();

//                Assert.NotNull(categories);
//                Assert.Empty(categories);
//                Assert.IsType<List<Season>>(categories);
//            }
//        }

//        [Fact]
//        public async void GetAll_ShouldReturnAListOfCategoryWithCorrectValues_WhenCategoriesExist()
//        {
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var expectedCategories = CreateCategoryList();
//                var repository = new RepositoryConcreteClass(context);
//                var categoryList = await repository.GetAll();

//                Assert.Equal(3, categoryList.Count);
//                Assert.Equal(expectedCategories[0].Id, categoryList[0].Id);
//                Assert.Equal(expectedCategories[0].Name, categoryList[0].Name);
//                Assert.Equal(expectedCategories[1].Id, categoryList[1].Id);
//                Assert.Equal(expectedCategories[1].Name, categoryList[1].Name);
//                Assert.Equal(expectedCategories[2].Id, categoryList[2].Id);
//                Assert.Equal(expectedCategories[2].Name, categoryList[2].Name);
//            }
//        }

//        [Fact]
//        public async void GetById_ShouldReturnCategoryWithSearchedId_WhenCategoryWithSearchedIdExist()
//        {
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);
//                var category = await repository.GetById(2);

//                Assert.NotNull(category);
//                Assert.IsType<Season>(category);
//            }
//        }

//        [Fact]
//        public async void GetById_ShouldReturnNull_WhenCategoryWithSearchedIdDoesNotExist()
//        {
//            await BookStoreHelperTests.CleanDataBase(_options);

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);
//                var category = await repository.GetById(1);

//                Assert.Null(category);
//            }
//        }

//        [Fact]
//        public async void GetById_ShouldReturnCategoryWithCorrectValues_WhenCategoryExist()
//        {
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);

//                var expectedCategories = CreateCategoryList();
//                var category = await repository.GetById(2);

//                Assert.Equal(expectedCategories[1].Id, category.Id);
//                Assert.Equal(expectedCategories[1].Name, category.Name);
//            }
//        }

//        [Fact]
//        public async void AddCategory_ShouldAddCategoryWithCorrectValues_WhenCategoryIsValid()
//        {
//            Season categoryToAdd = new Season();

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);
//                categoryToAdd = CreateCategory();

//                await repository.Add(categoryToAdd);
//            }

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var categoryResult = await context.Categories.Where(b => b.Id == 4).FirstOrDefaultAsync();

//                Assert.NotNull(categoryResult);
//                Assert.IsType<Season>(categoryToAdd);
//                Assert.Equal(categoryToAdd.Id, categoryResult.Id);
//                Assert.Equal(categoryToAdd.Name, categoryResult.Name);
//            }
//        }

//        [Fact]
//        public async void UpdateCategory_ShouldUpdateCategoryWithCorrectValues_WhenCategoryIsValid()
//        {
//            Season categoryToUpdate = new Season();
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                categoryToUpdate = await context.Categories.Where(b => b.Id == 1).FirstOrDefaultAsync();
//                categoryToUpdate.Name = "Updated Name";
//            }

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);
//                await repository.Update(categoryToUpdate);
//            }

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var updatedCategory = await context.Categories.Where(b => b.Id == 1).FirstOrDefaultAsync();

//                Assert.NotNull(updatedCategory);
//                Assert.IsType<Season>(updatedCategory);
//                Assert.Equal(categoryToUpdate.Id, updatedCategory.Id);
//                Assert.Equal(categoryToUpdate.Name, updatedCategory.Name);
//            }
//        }

//        [Fact]
//        public async void Remove_ShouldRemoveCategory_WhenCategoryIsValid()
//        {
//            Season categoryToRemove = new Season();

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                categoryToRemove = await context.Categories.Where(c => c.Id == 2).FirstOrDefaultAsync();
//            }

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var repository = new RepositoryConcreteClass(context);

//                await repository.Remove(categoryToRemove);
//            }

//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var categoryRemoved = await context.Categories.Where(c => c.Id == 2).FirstOrDefaultAsync();

//                Assert.Null(categoryRemoved);
//            }
//        }

//        private Season CreateCategory()
//        {
//            return new Season()
//            {
//                Id = 4,
//                Name = "Category Test 4",
//            };
//        }

//        private List<Season> CreateCategoryList()
//        {
//            return new List<Season>()
//            {
//                new Season { Id = 1, Name = "Category Test 1" },
//                new Season { Id = 2, Name = "Category Test 2" },
//                new Season { Id = 3, Name = "Category Test 3" }
//            };
//        }

//    }
//}

//internal class RepositoryConcreteClass : Repository<Season>
//{
//    internal RepositoryConcreteClass(VideoCatalogDbContext bookStoreDbContext) : base(bookStoreDbContext)
//    {

//    }
//}
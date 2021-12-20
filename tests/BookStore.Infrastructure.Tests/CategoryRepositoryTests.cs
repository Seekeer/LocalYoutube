//using System.Collections.Generic;
//using System.Linq;
//using BookStore.Domain.Models;
//using BookStore.Infrastructure.Context;
//using BookStore.Infrastructure.Repositories;
//using Microsoft.EntityFrameworkCore;
//using Xunit;

//namespace BookStore.Infrastructure.Tests
//{
//    public class CategoryRepositoryTests
//    {
//        private readonly DbContextOptions<VideoCatalogDbContext> _options;

//        /// <summary>
//        /// The CategoryRepository class only use the methods from the Repository base class
//        /// </summary>
//        public CategoryRepositoryTests()
//        {
//            // Use this when using a SQLite InMemory database
//            _options = BookStoreHelperTests.BookStoreDbContextOptionsSQLiteInMemory();
//            BookStoreHelperTests.CreateDataBaseSQLiteInMemory(_options);

//            // Use this when using a EF Core InMemory database
//            //_options = BookStoreHelperTests.BookStoreDbContextOptionsEfCoreInMemory();
//            //BookStoreHelperTests.CreateDataBaseEfCoreInMemory(_options);
//        }

//        [Fact]
//        public async void GetAll_ShouldReturnAListOfCategory_WhenCategoriesExist()
//        {
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var categoryRepository = new SeasonRepository(context);

//                var categories = await categoryRepository.GetAll();

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
//                var categoryRepository = new SeasonRepository(context);
//                var categories = await categoryRepository.GetAll();

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
//                var categoryRepository = new SeasonRepository(context);
//                var categoryList = await categoryRepository.GetAll();

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
//                var categoryRepository = new SeasonRepository(context);
//                var category = await categoryRepository.GetById(2);

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
//                var categoryRepository = new SeasonRepository(context);
//                var category = await categoryRepository.GetById(1);

//                Assert.Null(category);
//            }
//        }

//        [Fact]
//        public async void GetById_ShouldReturnCategoryWithCorrectValues_WhenCategoryExist()
//        {
//            await using (var context = new VideoCatalogDbContext(_options))
//            {
//                var categoryRepository = new SeasonRepository(context);

//                var expectedCategories = CreateCategoryList();
//                var category = await categoryRepository.GetById(2);

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
//                var categoryRepository = new SeasonRepository(context);
//                categoryToAdd = CreateCategory();

//                await categoryRepository.Add(categoryToAdd);
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
//                var categoryRepository = new SeasonRepository(context);
//                await categoryRepository.Update(categoryToUpdate);
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
//                var categoryRepository = new SeasonRepository(context);

//                await categoryRepository.Remove(categoryToRemove);
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
//                new Season {Id = 1, Name = "Category Test 1"},
//                new Season {Id = 2, Name = "Category Test 2"},
//                new Season {Id = 3, Name = "Category Test 3"}
//            };
//        }
//    }
//}
//
//  XKDataSQLite.m
//  XKDataSQLite_Example
//
//  Created by ALLen、 LAS on 2019/8/13.
//  Copyright © 2019 RyanMans. All rights reserved.
//

#import "XKDataSQLite.h"
#import "FMDB.h"
#import <sqlite3.h>

#define MinSleep()     [NSThread sleepForTimeInterval:0.01]

@implementation FMResultSet (xk)
- (NSMutableDictionary *)columnNameToIndexKey{
    int columnCount = sqlite3_column_count([self.statement statement]);
    NSMutableDictionary * columnNameToIndexKey = [[NSMutableDictionary alloc] initWithCapacity:(NSUInteger)columnCount];
    for (int index = 0; index < columnCount; index ++) {
        NSString * value = [NSString stringWithUTF8String:sqlite3_column_name([self.statement statement], index)];
        [columnNameToIndexKey setObject:value forKey:value.lowercaseString];
    }
    return columnNameToIndexKey;
}

- (NSDictionary*)toDictionary{
    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];
    [[self columnNameToIndexMap].allKeys enumerateObjectsUsingBlock:^(NSString*  _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [dictionary setObject:[self objectForColumn:key] forKey:[self columnNameToIndexKey][key]];
    }];
    return dictionary;
}
@end

//更新
typedef void(^DataSQLiteUpdateBlock)(FMDatabase * database,BOOL state);

//查询
typedef void(^DataSQLiteQueryBlock)(FMDatabase * database,FMResultSet * resultSet);

//数据库操作
@interface XKDataSQLite ()
@property (nonatomic,assign)BOOL isLock;
@property (nonatomic,strong)dispatch_queue_t dbQueue;
@property (nonatomic,strong)FMDatabase * fmdb;
@end

@implementation XKDataSQLite

- (instancetype)init{
    self = [super init];
    if (self) {
        _dbQueue = dispatch_queue_create("isRun.thread.com", 0);
        dispatch_queue_set_specific(_dbQueue, &_isLock, &_isLock, NULL);
    }
    return self;
}

//序列化行数据
- (NSDictionary*)dictionaryToDBColumnNameAndTypes:(NSDictionary*)data{
    NSMutableDictionary * temp = data ? data.mutableCopy:[NSMutableDictionary dictionary];
    [temp.allKeys enumerateObjectsUsingBlock:^(NSString *  _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([temp[key] isKindOfClass:[NSString class]]) {temp[key] = @"text DEFAULT ('')";}
        else if ([temp[key] isKindOfClass:[NSNumber class]]){temp[key] = @"numeric DEFAULT (0)";}
    }];
    return temp;
}

//主线程
- (BOOL)isMainThread{
    void *value = dispatch_get_specific(&_isLock);
    return (value == &_isLock);
}

#pragma mark - 数据库操作
//打开数据库
- (BOOL)open:(NSString*)path{
    if ([self isMainThread])return [self sc_open:path];
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_open:path];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_open:(NSString*)path{
    //拿到数据库对象，打开数据库，如果这个数据库不存在，就会自动创建
    FMDatabase *temp = [FMDatabase databaseWithPath:path];
    if ([temp open] == NO) return NO;
    _fmdb = temp;
    _dBFilePath = path;
    return YES;
}

//关闭数据库
- (BOOL)close{
    if ([self isMainThread]) return [self sc_close];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_close];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_close{
    if ([_fmdb close] == NO) return NO;
    _dBFilePath = nil;
    _fmdb = nil;
    return YES;
}

//判断表是否存在
- (BOOL)isExistsDataTable:(NSString*)tableName{
    if ([self isMainThread]) return [self sc_isExistsDataTable:tableName];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_isExistsDataTable:tableName];
        self->_isLock = NO;
    });
    
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_isExistsDataTable:(NSString*)tableName{
    NSString * sql = [NSString stringWithFormat:@"SELECT count(*) FROM sqlite_master WHERE type='table' AND name='%@' LIMIT 1", tableName];
    __block BOOL state = NO;
    [self sc_executeQueryWithSQL:sql parameters:nil block:^(FMDatabase *database, FMResultSet *resultSet) {
        if ([resultSet next] == NO) return ;
        state = [resultSet boolForColumnIndex:0];
    }];
    return state;
}

//创建表
- (BOOL)createDataTable:(NSString*)sql{
    if ([self isMainThread]) return [self sc_createDataTable:sql];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    
    dispatch_async(_dbQueue, ^{
        state = [self sc_createDataTable:sql];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_createDataTable:(NSString*)sql{
    [self executeUpdateWithSQL:sql parameters:nil block:nil];
    return  YES;
}

//根据一个字典创建表
- (BOOL)createDataTable:(NSString*)tableName withDictionary:(NSDictionary*)dictionary{
    if ([self isMainThread]) return [self sc_createDataTable:tableName withDictionary:dictionary];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    
    dispatch_async(_dbQueue, ^{
        state = [self sc_createDataTable:tableName withDictionary:dictionary];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
    
}

- (BOOL)sc_createDataTable:(NSString*)tableName withDictionary:(NSDictionary*)dictionary{
    return [self sc_createDataTable:tableName withTypeData:[self dictionaryToDBColumnNameAndTypes:dictionary]];
}

//类型字典
- (BOOL)sc_createDataTable:(NSString*)tableName withTypeData:(NSDictionary*)data{
    NSMutableString * buffer = [[NSMutableString alloc] initWithFormat:@"\"%@\" %@",data.allKeys.firstObject,data[data.allKeys.firstObject]];
    NSMutableArray * temp = data.allKeys.mutableCopy;
    [temp removeObjectAtIndex:0];
    [temp enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [buffer appendFormat:@", \"%@\" %@", key, data[key]];
    }];
    return [self sc_createDataTable:tableName columnName:buffer,nil];
}

- (BOOL)sc_createDataTable:(NSString*)tableName columnName:(NSString *)name, ...{
    NSMutableString * buffer = [[NSMutableString alloc] initWithFormat:@"create table '%@' (%@", tableName, name];
    va_list ap;
    va_start(ap, name);
    name = va_arg(ap, NSString *);
    while (name){
        [buffer appendFormat:@", %@", name];
        name = va_arg(ap, NSString *);
    }
    va_end(ap);
    [buffer appendString:@")"];
    return [self sc_executeUpdateWithSQL:buffer parameters:nil block:nil];
}

//MARK:判断表中 是否存在某条数据
- (BOOL)isExistsRowWithTable:(NSString*)tableName indexName:(NSString*)indexName indexData:(id)indexData{
    NSString * sql = [NSString stringWithFormat:@"SELECT count(*) FROM '%@' WHERE \"%@\" = ? LIMIT 1", tableName, indexName];
    __block BOOL state = NO;
    [self executeQueryWithSQL:sql parameters:@[indexData] block:^(FMDatabase *database, FMResultSet *resultSet) {
        if ([resultSet next] == YES) {
            state = [resultSet longForColumnIndex:0];
        }
    }];
    return state;
}

//插入表
- (BOOL)insertDataWithTable:(NSString *)tableName columnData:(NSDictionary *)columnData{
    if ([self isMainThread]) return [self sc_insertDataWithTable:tableName columnData:columnData];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_insertDataWithTable:tableName columnData:columnData];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_insertDataWithTable:(NSString *)tableName columnData:(NSDictionary *)columnData{
    if (!columnData.count) return NO;
    NSMutableString * names = [[NSMutableString alloc] initWithFormat:@"'%@'", columnData.allKeys.firstObject];
    NSMutableString * values = [[NSMutableString alloc] initWithString:@"?"];
    for (NSInteger index = 1; index < columnData.allKeys.count; index ++) {
        [names appendFormat:@", '%@'", columnData.allKeys[index]];
        [values appendString:@", ?"];
    }
    
    NSString * sql = [NSString stringWithFormat:@"insert into '%@' (%@) values(%@)", tableName, names, values];
    NSMutableArray * parameters = [NSMutableArray array];
    [columnData.allKeys enumerateObjectsUsingBlock:^(NSString *  _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [parameters addObject:columnData[key]];
    }];
    return [self sc_executeUpdateWithSQL:sql parameters:parameters block:nil];
}

//更新表
- (BOOL)updateDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData columnData:(NSDictionary *)columnData{
    if ([self isMainThread]) return [self sc_updateDataWithTable:tableName indexName:indexName indexData:indexData columnData:columnData];
    
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_updateDataWithTable:tableName indexName:indexName indexData:indexData columnData:columnData];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_updateDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData columnData:(NSDictionary *)columnData{
    NSMutableString * updateStr = [[NSMutableString alloc] initWithFormat:@"UPDATE '%@' SET '%@' = ?", tableName, columnData.allKeys.firstObject];
    for (NSInteger index = 1; index < columnData.allKeys.count; index ++) {
        [updateStr appendFormat:@", '%@' = ?", columnData.allKeys[index]];
    }
    [updateStr appendFormat:@" WHERE \"%@\" = ?", indexName];
    
    NSMutableArray * parameters = [NSMutableArray array];
    [columnData.allKeys enumerateObjectsUsingBlock:^(NSString *  _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [parameters addObject:columnData[key]];
    }];
    [parameters addObject:indexData];
    return [self sc_executeUpdateWithSQL:updateStr parameters:parameters block:nil];
}

//MARK:更新表中数据，如不存在则插入
- (BOOL)autoUpdateWithTable:(NSString *)tableName columnData:(NSDictionary *)columnData indexName:(NSString *)indexName indexData:(id)indexData{
    if (nil == indexData) return NO;
    if ([self isMainThread]) return [self sc_autoUpdateWithTable:tableName columnData:columnData indexName:indexName indexData:indexData];
    
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_autoUpdateWithTable:tableName columnData:columnData indexName:indexName indexData:indexData];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_autoUpdateWithTable:(NSString *)tableName columnData:(NSDictionary *)columnData indexName:(NSString *)indexName indexData:(id)indexData{
    if (nil == indexData) indexData = columnData[indexName];
    return [self isExistsRowWithTable:tableName indexName:indexName indexData:indexData] ? [self updateDataWithTable:tableName indexName:indexName indexData:indexData columnData:columnData]:[self insertDataWithTable:tableName columnData:columnData];
}

#pragma mark --删除
- (BOOL)deleteTable:(NSString*)tableName{
    if ([self isMainThread]) return [self sc_deleteTable:tableName];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_deleteTable:tableName];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_deleteTable:(NSString*)tableName{
    return [self executeUpdateWithSQL:[NSString stringWithFormat:@"drop table '%@'", tableName] parameters:nil block:nil];
}

//MARK: 删除表中某条数据
- (BOOL)deleteDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData{
    if (nil == indexData) return NO;
    if ([self isMainThread]) return [self sc_deleteDataWithTable:tableName indexName:indexName indexData:indexData];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_deleteDataWithTable:tableName indexName:indexName indexData:indexData];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_deleteDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData{
    return [self sc_executeUpdateWithSQL:[NSString stringWithFormat:@"delete from '%@' where \"%@\" = ?", tableName, indexName] parameters:@[indexData] block:nil];
}

#pragma mark - 清空
- (BOOL)cleanTable:(NSString*)tableName{
    if ([self isMainThread]) return [self sc_cleanTable:tableName];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{
        state = [self sc_cleanTable:tableName];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (BOOL)sc_cleanTable:(NSString*)tableName{
    return [self executeUpdateWithSQL:[NSString stringWithFormat:@"delete from '%@'", tableName] parameters:nil block:nil];
}

#pragma mark - 查询
//MARK: 获取表中某条数据
- (NSDictionary*)queryDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData{
    if (nil == indexData) return nil;
    if ([self isMainThread]) return [self sc_queryDataWithTable:tableName indexName:indexName indexData:indexData];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block NSDictionary *state = nil;
    dispatch_async(_dbQueue, ^{
        state = [self sc_queryDataWithTable:tableName indexName:indexName indexData:indexData];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (NSDictionary*)sc_queryDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData{
    NSString * sql = [NSString stringWithFormat:@"select * from '%@' where \"%@\" = ? LIMIT 1", tableName, indexName];
    __block NSDictionary *temp = nil;
    [self sc_executeQueryWithSQL:sql parameters:@[indexData] block:^(FMDatabase *database, FMResultSet *resultSet) {
        if ([resultSet next] == YES) {
            temp = [resultSet toDictionary];
        }
    }];
    return temp;
}

//MARK: 获取表中全部数据
- (NSArray*)queryAllDataWithTable:(NSString*)tableName{
    if ([self isMainThread]) return [self sc_queryAllDataWithTable:tableName];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block NSArray *state = nil;
    dispatch_async(_dbQueue, ^{
        state = [self sc_queryAllDataWithTable:tableName];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

- (NSArray*)sc_queryAllDataWithTable:(NSString*)tableName{
    NSString * sql = [NSString stringWithFormat:@"select * from '%@'", tableName];
    __block NSMutableArray *result = nil;
    [self sc_executeQueryWithSQL:sql parameters:nil block:^(FMDatabase *database, FMResultSet *resultSet) {
        if ([resultSet next] == NO) return ;
        result = [NSMutableArray array];
        do{
            NSDictionary *temp = [resultSet toDictionary];
            [result addObject:temp];
        }while ([resultSet next]);
    }];
    
    return result;
}

#pragma mark - 基础:更新 查询
//更新数据
- (BOOL)executeUpdateWithSQL:(NSString*)sql parameters:(NSArray*)parameters block:(DataSQLiteUpdateBlock)block{
    if ([self isMainThread])return [self sc_executeUpdateWithSQL:sql parameters:parameters block:block];
    while (_isLock) MinSleep();
    _isLock = YES;
    __block BOOL state = NO;
    dispatch_async(_dbQueue, ^{  //异步存储
        state = [self sc_executeUpdateWithSQL:sql parameters:parameters block:block];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
    return state;
}

//更新存储数据
- (BOOL)sc_executeUpdateWithSQL:(NSString*)sql parameters:(NSArray*)parameters block:(DataSQLiteUpdateBlock)block{
    if ([_fmdb executeUpdate:sql withArgumentsInArray:parameters]) {
        if (block) block(_fmdb,YES);
        return YES;
    }
    if (block) block(_fmdb,NO);
    return NO;
}

//查询数据
- (void)executeQueryWithSQL:(NSString*)sql parameters:(NSArray*)parameters block:(DataSQLiteQueryBlock)block{
    if ([self isMainThread])return [self sc_executeQueryWithSQL:sql parameters:parameters block:block];
    while (_isLock) MinSleep();
    _isLock = YES;
    dispatch_async(_dbQueue, ^{
        [self sc_executeQueryWithSQL:sql parameters:parameters block:block];
        self->_isLock = NO;
    });
    while (_isLock) MinSleep();
}

//查询数据
- (void)sc_executeQueryWithSQL:(NSString*)sql parameters:(NSArray*)parameters block:(DataSQLiteQueryBlock)block{
    FMResultSet * resultSet = [_fmdb executeQuery:sql withArgumentsInArray:parameters];
    if (block) block(_fmdb,resultSet);
    [resultSet close];
}
@end

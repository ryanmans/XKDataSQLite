//
//  XKDataSQLite.h
//  XKDataSQLite_Example
//
//  Created by ALLen、 LAS on 2019/8/13.
//  Copyright © 2019 RyanMans. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XKDataSQLite : NSObject
@property (nonatomic,strong,readonly)NSString * dBFilePath;

/**
 打开数据库
 
 @param path 路径
 @return   yes ／ no
 */
- (BOOL)open:(NSString*)path;

/**
 关闭数据库
 */
- (BOOL)close;

/**
 判断表是否存在
 
 @param tableName table name
 @return  yes ／ no
 */
- (BOOL)isExistsDataTable:(NSString*)tableName;

/**
 创建表
 
 @param sql sql 语句
 @return  yes ／ no
 */
- (BOOL)createDataTable:(NSString*)sql;

/**
 根据一个字典 创建表（慎用）
 
 @param tableName table name
 @param dictionary 数据
 @return yes ／ no
 */
- (BOOL)createDataTable:(NSString*)tableName withDictionary:(NSDictionary*)dictionary;

/**
 判断表中 是否存在某条数据
 
 @param tableName table name
 @param indexName key
 @param indexData value
 @return yes ／ no
 */
- (BOOL)isExistsRowWithTable:(NSString*)tableName indexName:(NSString*)indexName indexData:(id)indexData;

/**
 插入表数据
 
 @param tableName table name
 @param columnData data
 @return yes ／ no
 */
- (BOOL)insertDataWithTable:(NSString *)tableName columnData:(NSDictionary *)columnData;

/**
 更新表数据
 
 @param tableName table name
 @param indexName key
 @param indexData value
 @param columnData  data
 @return yes / no
 */
- (BOOL)updateDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData columnData:(NSDictionary *)columnData;

/**
 更新表中数据，如不存在则插入
 
 @param tableName table name
 @param columnData data
 @param indexName key
 @param indexData value
 @return yes / no
 */
- (BOOL)autoUpdateWithTable:(NSString *)tableName columnData:(NSDictionary *)columnData indexName:(NSString *)indexName indexData:(id)indexData;

/**
 删除表
 
 @param tableName table name
 @return yes / no
 */
- (BOOL)deleteTable:(NSString*)tableName;

/**
 删除表中某条数据
 
 @param tableName table
 @param indexName key
 @param indexData value
 @return yes／no
 */
- (BOOL)deleteDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData;

/**
 清空表
 
 @param tableName table name
 @return yes / no
 */
- (BOOL)cleanTable:(NSString*)tableName;

/**
 查找表中某条数据
 
 @param tableName table name
 @param indexName key
 @param indexData value
 @return yes / no
 */
- (NSDictionary*)queryDataWithTable:(NSString *)tableName indexName:(NSString *)indexName indexData:(id)indexData;

/**
 获取表中全部数据
 
 @param tableName table name
 @return yes/no
 */
- (NSArray*)queryAllDataWithTable:(NSString*)tableName;
@end

NS_ASSUME_NONNULL_END
